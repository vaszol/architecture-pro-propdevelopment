#!/bin/bash

echo "=== ПРИВЯЗКА ГРУПП К РОЛЯМ ==="

echo "1. Привязка группы viewers к ClusterRole cluster-viewer..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-binding
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

echo "2. Привязка группы operators к ClusterRole cluster-operator..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: operators-cluster-binding
subjects:
- kind: Group
  name: operators
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-operator
  apiGroup: rbac.authorization.k8s.io
EOF

echo "3. Привязка группы operators к Role namespace-operator в development..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operators-namespace-binding
  namespace: development
subjects:
- kind: Group
  name: operators
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-operator
  apiGroup: rbac.authorization.k8s.io
EOF

echo "4. Привязка группы operators к Role namespace-operator в production..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operators-production-binding
  namespace: production
subjects:
- kind: Group
  name: operators
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-operator
  apiGroup: rbac.authorization.k8s.io
EOF

echo "5. Привязка группы auditors к ClusterRole cluster-auditor..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: auditors-binding
subjects:
- kind: Group
  name: auditors
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-auditor
  apiGroup: rbac.authorization.k8s.io
EOF

echo "6. Привязка группы security к Role security-specialist..."
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: security-binding
  namespace: security
subjects:
- kind: Group
  name: security
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: security-specialist
  apiGroup: rbac.authorization.k8s.io
EOF

echo "7. Привязка конкретных пользователей к группам..."
echo "   (Для демонстрации привязываем пользователей напрямую)"

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewer1-binding
subjects:
- kind: User
  name: viewer1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: operator1-binding
subjects:
- kind: User
  name: operator1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator1-namespace-binding
  namespace: development
subjects:
- kind: User
  name: operator1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator1-production-binding
  namespace: production
subjects:
- kind: User
  name: operator1
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-operator
  apiGroup: rbac.authorization.k8s.io
EOF

echo "=== ПРОВЕРКА СОЗДАННЫХ ПРИВЯЗОК ==="
echo ""
echo "ClusterRoleBindings:"
kubectl get clusterrolebindings | grep -E "(viewers|operators|auditors)"
echo ""
echo "RoleBindings в development:"
kubectl get rolebindings -n development
echo ""
echo "RoleBindings в production:"
kubectl get rolebindings -n production
echo ""
echo "RoleBindings в security:"
kubectl get rolebindings -n security
