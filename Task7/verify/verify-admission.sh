#!/bin/bash

echo "=== Проверка Pod Security Admission ==="
echo ""

# Проверяем метки namespace
echo "1. Проверка меток namespace audit-zone:"
kubectl get namespace audit-zone -o jsonpath='{.metadata.labels}' | jq .
echo ""

# Пробуем применить небезопасные манифесты
echo "2. Попытка создания привилегированного пода:"
kubectl apply -f insecure-manifests/01-privileged-pod.yaml 2>&1 | grep -A5 -B5 "Error"
echo ""

echo "3. Попытка создания пода с hostPath:"
kubectl apply -f insecure-manifests/02-hostpath-pod.yaml 2>&1 | grep -A5 -B5 "Error"
echo ""

echo "4. Попытка создания пода с root user:"
kubectl apply -f insecure-manifests/03-root-user-pod.yaml 2>&1 | grep -A5 -B5 "Error"
echo ""

echo "5. Проверка Gatekeeper constraints:"
kubectl get constraints -A -o wide
echo ""

echo "6. Проверка ConstraintTemplates:"
kubectl get constrainttemplates -o wide
echo ""

echo "7. Проверка статуса Gatekeeper:"
kubectl get pods -n gatekeeper-system -o wide
echo ""

echo "8. Проверка логов Gatekeeper (детально):"
kubectl logs -n gatekeeper-system -l control-plane=controller-manager --tail=100 2>&1 | grep -E -i "violation|denied|error|audit|constraint" | head -20
echo ""

