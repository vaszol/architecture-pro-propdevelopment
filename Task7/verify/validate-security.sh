#!/bin/bash

echo "=== Проверка безопасных манифестов ==="
echo ""

# Создаем конфигмап для теста
kubectl create configmap nginx-config --from-literal=index.html="Hello Secure World" -n audit-zone 2>/dev/null || true

echo "1. Создание безопасных подов:"
for file in secure-manifests/*.yaml; do
    echo "Применение $(basename $file):"
    kubectl apply -f "$file"
    if [ $? -eq 0 ]; then
        echo "✓ Успешно создан"
    else
        echo "✗ Ошибка создания"
    fi
    echo ""
done

echo "2. Статус подов в audit-zone:"
kubectl get pods -n audit-zone -o wide
echo ""

echo "3. Проверка securityContext:"
kubectl get pod -n audit-zone -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext}{"\n"}{end}'
echo ""

echo "4. Проверка событий:"
kubectl get events -n audit-zone --sort-by='.lastTimestamp'