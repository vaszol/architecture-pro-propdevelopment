# Отчёт по результатам анализа Kubernetes Audit Log

## Подозрительные события

1. Доступ к секретам:
   - Кто: system:apiserver
   - Где: namespace=не указан, ресурс=secrets, имя=—
   - Почему подозрительно: Сервис-аккаунт читает secrets (верб=list). Может указывать на разведку прав.

2. Привилегированные поды:
   - Кто: system:serviceaccount:kube-system:daemon-set-controller
   - Комментарий: Создан pod с privileged=true — потенциальная эскалация до узла.

3. Использование kubectl exec в чужом поде:
   - Не обнаружено.

4. Создание RoleBinding с правами cluster-admin:
   - Не обнаружено.

5. Удаление audit-policy.yaml:
   - Не обнаружено.

## Вывод

- Найдено событий: 26. Из них: secrets-access=24, privileged-pod=2, cross-namespace-exec=0, cluster-admin-binding=0, audit-policy-tamper=0.
- Компрометацией кластера можно считать: создание привилегированного pod, exec в системном namespace, выдачу cluster-admin через RoleBinding, а также попытку/факт отключения аудита.
- Недочёты RBAC-политики: отсутствие ограничений на создание привилегированных pod'ов; возможность читать secrets из чужих namespace; возможность связывать ServiceAccount с cluster-admin.

### Приложение: сводка по актёрам (top):
- system:apiserver: 10
- system:kube-controller-manager: 8
- minikube-user: 4
- kubernetes-admin: 2
- system:serviceaccount:kube-system:daemon-set-controller: 1
- system:serviceaccount:secure-ops:monitoring: 1