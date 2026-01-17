Задание 7. Аудит и обеспечение соответствия политике безопасности контейнеров

## Настройте среду Minikube
```shell
minikube stop
minikube delete
```
```shell
mkdir -p ~/.minikube/files/etc/ssl/certs
cp "./audit-policy.yaml" ~/.minikube/files/etc/ssl/certs/audit-policy.yaml
```
```shell
minikube start --driver=docker --cpus=4 --memory=6g \
--extra-config=apiserver.audit-log-path=- \
--extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml
```
```shell
minikube addons enable metrics-server
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
```
```shell
minikube status
```
## Создание namespace и настройка PodSecurity
```shell
kubectl apply -f 01-create-namespace.yaml
```

## Установите Gatekeeper
```shell
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
# Дождитесь запуска
kubectl get pods -n gatekeeper-system --watch
```
## после ожидания все pod в статусе Running
```shell
kubectl get pods -n gatekeeper-system 
```

## Применение ConstraintTemplates
```shell
kubectl apply -f gatekeeper/constraint-templates/
```
## Применение Constraints
```shell
kubectl apply -f gatekeeper/constraints/
```

## Проверка работы
### Тест 1: Проверка блокировки небезопасных конфигураций
```shell
chmod +x verify/verify-admission.sh  

./verify/verify-admission.sh
```

### Тест 2: Проверка работы безопасных конфигураций
```shell
chmod +x verify/validate-security.sh  

./verify/validate-security.sh
```

### Тест 3: Проверка Gatekeeper
```shell
kubectl get constraints -A
kubectl logs -n gatekeeper-system -l control-plane=controller-manager --tail=20
```
### Тест 4: Проверка аудита
```shell
minikube ssh "sudo tail -f /var/log/audit.log | grep -i 'audit-zone\|violation\|denied'"
```
