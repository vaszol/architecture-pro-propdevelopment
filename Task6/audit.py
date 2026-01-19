#!/usr/bin/env python3

import argparse, json, os, sys, re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

def safe_get(d: Dict, path: str, default=None):
    cur = d
    for key in path.split("."):
        if not isinstance(cur, dict):
            return default
        cur = cur.get(key, None)
        if cur is None:
            return default
    return cur

def as_utc_iso(ts: str) -> str:
    try:
        return datetime.fromisoformat(ts.replace("Z","+00:00")).astimezone(timezone.utc).isoformat()
    except Exception:
        return ts

def iter_events(log_path: Path):
    with log_path.open("r", encoding="utf-8", errors="ignore") as f:
        for ln, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
                yield ev
            except json.JSONDecodeError:

                continue

def is_privileged_pod_create(ev: Dict[str, Any]) -> bool:
    if safe_get(ev, "verb") != "create":
        return False
    if safe_get(ev, "objectRef.resource") != "pods":
        return False
    ro = ev.get("requestObject") or {}
    containers = safe_get(ro, "spec.containers") or []
    for c in containers:
        if safe_get(c, "securityContext.privileged") is True:
            return True
    if safe_get(ro, "spec.securityContext.privileged") is True:
        return True
    return False

def is_exec_other_ns(ev: Dict[str, Any], home_ns: Optional[str]) -> bool:
    if safe_get(ev, "objectRef.resource") != "pods":
        return False
    if safe_get(ev, "objectRef.subresource") != "exec":
        uri = safe_get(ev, "requestURI") or ""
        if "/exec" not in uri:
            return False
    if safe_get(ev, "verb") not in ("create","patch"):  # some kubectl versions PATCH for SPDY
        return False
    ns = safe_get(ev, "objectRef.namespace")
    if home_ns and ns and ns != home_ns:
        return True
    # if no home_ns given, still treat any exec into kube-system as sensitive
    if ns == "kube-system":
        return True
    return False

def is_secrets_access(ev: Dict[str, Any]) -> bool:
    if safe_get(ev, "objectRef.resource") != "secrets":
        return False
    if safe_get(ev, "verb") not in ("get","list","watch"):
        return False
    return True

def is_audit_policy_tamper(ev: Dict[str, Any]) -> bool:
    # Heuristics: delete on ConfigMap/Policy named like "audit", or requestURI mentions audit-policy
    if safe_get(ev, "verb") == "delete":
        name = (safe_get(ev, "objectRef.name") or "").lower()
        res = (safe_get(ev, "objectRef.resource") or "").lower()
        uri = (safe_get(ev, "requestURI") or "").lower()
        kind = (safe_get(ev, "objectRef.apiGroup") or "") + "/" + (safe_get(ev, "objectRef.resource") or "")
        if "audit" in name or "audit" in uri:
            if res in ("configmaps","policies","secrets","cm"):
                return True
            # Some labs may attempt to delete a non-existent "Policy"; still suspicious
            return True
    return False

def is_escalating_rolebinding(ev: Dict[str, Any]) -> bool:
    if safe_get(ev, "verb") != "create":
        return False
    res = safe_get(ev, "objectRef.resource")
    if res not in ("rolebindings","clusterrolebindings"):
        return False
    ro = ev.get("requestObject") or {}
    role_ref = safe_get(ro, "roleRef.name")
    return (role_ref == "cluster-admin")

def is_self_sar(ev: Dict[str, Any]) -> bool:
    # kubectl auth can-i => create SelfSubjectAccessReview
    if safe_get(ev, "verb") != "create":
        return False
    if safe_get(ev, "objectRef.apiGroup") != "authorization.k8s.io":
        return False
    if safe_get(ev, "objectRef.resource") not in ("selfsubjectaccessreviews", "subjectaccessreviews"):
        return False
    return True

def severity_and_tag(ev: Dict[str, Any], home_ns: Optional[str]):
    tags = []
    sev = "low"
    if is_secrets_access(ev):
        tags.append("secrets-access")
        sev = max(sev, "medium", key=["low","medium","high","critical"].index)
    if is_privileged_pod_create(ev):
        tags.append("privileged-pod")
        sev = max(sev, "high", key=["low","medium","high","critical"].index)
    if is_exec_other_ns(ev, home_ns):
        tags.append("cross-namespace-exec")
        sev = max(sev, "high", key=["low","medium","high","critical"].index)
    if is_escalating_rolebinding(ev):
        tags.append("cluster-admin-binding")
        sev = max(sev, "critical", key=["low","medium","high","critical"].index)
    if is_audit_policy_tamper(ev):
        tags.append("audit-policy-tamper")
        sev = max(sev, "critical", key=["low","medium","high","critical"].index)
    if is_self_sar(ev):
        tags.append("auth-can-i")
        sev = max(sev, "low", key=["low","medium","high","critical"].index)
    return sev, tags

def slim_event(ev: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "stage": ev.get("stage"),
        "ts": as_utc_iso(safe_get(ev, "requestReceivedTimestamp") or ev.get("stageTimestamp") or ""),
        "user": safe_get(ev, "user.username"),
        "impersonatedUser": safe_get(ev, "impersonatedUser.username"),
        "verb": ev.get("verb"),
        "sourceIPs": ev.get("sourceIPs"),
        "userAgent": ev.get("userAgent"),
        "namespace": safe_get(ev, "objectRef.namespace"),
        "resource": safe_get(ev, "objectRef.resource"),
        "subresource": safe_get(ev, "objectRef.subresource"),
        "apiGroup": safe_get(ev, "objectRef.apiGroup"),
        "name": safe_get(ev, "objectRef.name"),
        "requestURI": ev.get("requestURI"),
        "responseCode": safe_get(ev, "responseStatus.code"),
        "audited_by_policyRule": safe_get(ev, "auditID"),  # auditID is unique; policy rule not exposed, but keeping ID
    }

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default="./audit.log", help="Path to Kubernetes audit log file (JSON lines).")
    ap.add_argument("--out", default="./", help="Output directory for audit-extract.json and analysis.md")
    ap.add_argument("--namespace", default="secure-ops", help="Home namespace for the simulation (used to flag cross-namespace exec)")
    args = ap.parse_args()

    log_path = Path(args.log)
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    suspicious: List[Dict[str, Any]] = []
    counters = {
        "secrets-access": 0,
        "privileged-pod": 0,
        "cross-namespace-exec": 0,
        "cluster-admin-binding": 0,
        "audit-policy-tamper": 0,
        "auth-can-i": 0,
    }
    actors = {}
    resources = {}

    for ev in iter_events(log_path):
        sev, tags = severity_and_tag(ev, args.namespace)
        if tags:
            e = slim_event(ev)
            e["severity"] = sev
            e["tags"] = tags
            suspicious.append(e)
            # rollups
            for t in tags:
                counters[t] += 1
            who = e.get("impersonatedUser") or e.get("user") or "unknown"
            actors.setdefault(who, 0)
            actors[who] += 1
            key = f"{e.get('namespace')}/{e.get('resource')}/{e.get('name')}"
            resources.setdefault(key, 0)
            resources[key] += 1

    # Save JSON extract
    extract_path = out_dir / "audit-extract.json"
    with extract_path.open("w", encoding="utf-8") as f:
        json.dump({"events": suspicious}, f, ensure_ascii=False, indent=2)

    # Build analysis.md
    def first(tag):
        for e in suspicious:
            if tag in e["tags"]:
                return e
        return None

    lines = []
    lines.append("# Отчёт по результатам анализа Kubernetes Audit Log\n")
    lines.append("## Подозрительные события\n")

    e = first("secrets-access")
    lines.append("1. Доступ к секретам:")
    if e:
        lines.append(f"   - Кто: {e.get('impersonatedUser') or e.get('user') or 'неизвестно'}")
        ns = e.get("namespace") or "не указан"
        lines.append(f"   - Где: namespace={ns}, ресурс={e.get('resource')}, имя={e.get('name') or '—'}")
        lines.append(f"   - Почему подозрительно: Сервис-аккаунт читает secrets (верб={e.get('verb')}). Может указывать на разведку прав.\n")
    else:
        lines.append("   - Не обнаружено.\n")

    e = first("privileged-pod")
    lines.append("2. Привилегированные поды:")
    if e:
        lines.append(f"   - Кто: {e.get('impersonatedUser') or e.get('user') or 'неизвестно'}")
        lines.append("   - Комментарий: Создан pod с privileged=true — потенциальная эскалация до узла.\n")
    else:
        lines.append("   - Не обнаружено.\n")


    e = first("cross-namespace-exec")
    lines.append("3. Использование kubectl exec в чужом поде:")
    if e:
        lines.append(f"   - Кто: {e.get('impersonatedUser') or e.get('user') or 'неизвестно'}")
        lines.append(f"   - Что делал: exec в pod {e.get('name') or '—'} в namespace={e.get('namespace')}. Возможный lateral movement.\n")
    else:
        lines.append("   - Не обнаружено.\n")


    e = first("cluster-admin-binding")
    lines.append("4. Создание RoleBinding с правами cluster-admin:")
    if e:
        lines.append(f"   - Кто: {e.get('impersonatedUser') or e.get('user') or 'неизвестно'}")
        lines.append("   - К чему привело: Эскалация до cluster-admin через RoleBinding/ClusterRoleBinding.\n")
    else:
        lines.append("   - Не обнаружено.\n")


    e = first("audit-policy-tamper")
    lines.append("5. Удаление audit-policy.yaml:")
    if e:
        lines.append(f"   - Кто: {e.get('impersonatedUser') or e.get('user') or 'неизвестно'}")
        lines.append("   - Возможные последствия: Отключение/ослабление аудита, усложнение расследования инцидента.\n")
    else:
        lines.append("   - Не обнаружено.\n")

    lines.append("## Вывод\n")
    total = len(suspicious)
    lines.append(f"- Найдено событий: {total}. Из них: "
                 f"secrets-access={counters['secrets-access']}, "
                 f"privileged-pod={counters['privileged-pod']}, "
                 f"cross-namespace-exec={counters['cross-namespace-exec']}, "
                 f"cluster-admin-binding={counters['cluster-admin-binding']}, "
                 f"audit-policy-tamper={counters['audit-policy-tamper']}.")
    lines.append("- Компрометацией кластера можно считать: создание привилегированного pod, exec в системном namespace, выдачу cluster-admin через RoleBinding, а также попытку/факт отключения аудита.")
    lines.append("- Недочёты RBAC-политики: отсутствие ограничений на создание привилегированных pod'ов; возможность читать secrets из чужих namespace; возможность связывать ServiceAccount с cluster-admin.")
    lines.append("\n### Приложение: сводка по актёрам (top):")
    if actors:
        top = sorted(actors.items(), key=lambda x: x[1], reverse=True)[:10]
        for who, cnt in top:
            lines.append(f"- {who}: {cnt}")
    else:
        lines.append("- нет данных")

    report_path = out_dir / "analysis.md"
    with report_path.open("w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Wrote {extract_path} and {report_path}")

if __name__ == "__main__":
    main()