#!/bin/bash

echo "Создание неймспейсов для разных отделов..."
kubectl create namespace development 2>/dev/null || true
kubectl create namespace production 2>/dev/null || true
kubectl create namespace security 2>/dev/null || true

echo "=== 1. СОЗДАНИЕ РОЛЕЙ ДЛЯ ГРУППЫ VIEWERS (ТОЛЬКО ПРОСМОТР) ==="

echo "Создание ClusterRole для просмотра кластера..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
# Базовые ресурсы для просмотра
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "namespaces", "nodes", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
# Ресурсы приложений
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch"]
# Batch ресурсы
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
# Сетевые ресурсы
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
# Storage ресурсы
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
# События
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
EOF

echo "=== 2. СОЗДАНИЕ РОЛЕЙ ДЛЯ ГРУППЫ OPERATORS (НАСТРОЙКА КЛАСТЕРА) ==="

echo "Создание ClusterRole для операторов кластера..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-operator
rules:
# Управление неймспейсами
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
# Управление узлами (ограниченно)
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch", "patch"]
# Управление PersistentVolumes
- apiGroups: [""]
  resources: ["persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
# Управление StorageClasses
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
# Управление сетевыми политиками
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
# Управление ресурсами кластера
- apiGroups: [""]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
# Управление ролями в своих неймспейсах
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
# Доступ к метрикам для мониторинга
- nonResourceURLs: ["/metrics", "/healthz", "/readyz"]
  verbs: ["get"]
EOF

echo "Создание Role для операторов в неймспейсах..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: namespace-operator
rules:
# Полное управление приложениями
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets"]
  verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
EOF

echo "=== 3. СОЗДАНИЕ РОЛЕЙ ДЛЯ ПРИВИЛЕГИРОВАННЫХ ГРУПП ==="

echo "Создание ClusterRole для аудиторов..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-auditor
rules:
# Просмотр всех ресурсов
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Просмотр RBAC
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Просмотр логов
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
EOF

echo "Создание Role для security специалистов..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: security
  name: security-specialist
rules:
# Полный доступ к секретам
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
# Просмотр других ресурсов для контекста
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
EOF

echo "=== 4. СОЗДАНИЕ ДОПОЛНИТЕЛЬНЫХ РОЛЕЙ ==="

echo "Создание Role для CI/CD оператора..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: cicd-operator
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
EOF

echo "Роли успешно созданы!"
echo ""
echo "Созданные роли:"
echo "1. cluster-viewer - для группы viewers (только просмотр)"
echo "2. cluster-operator - для группы operators (настройка кластера)"
echo "3. namespace-operator - для операторов в неймспейсах"
echo "4. cluster-auditor - для привилегированной группы auditors"
echo "5. security-specialist - для привилегированной группы security"
echo "6. cicd-operator - дополнительная роль для CI/CD"
