#!/bin/bash

echo "Создание пользователей и групп..."

# Создаем директорию для пользователей
mkdir -p users

# 1. Пользователь из группы viewers (только просмотр)
openssl genrsa -out users/viewer1.key 2048
openssl req -new -key users/viewer1.key -out users/viewer1.csr -subj "/CN=viewer1/O=viewers"
openssl x509 -req -in users/viewer1.csr -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key -CAcreateserial -out users/viewer1.crt -days 500

# 2. Пользователь из группы operators (настройка кластера)
openssl genrsa -out users/operator1.key 2048
openssl req -new -key users/operator1.key -out users/operator1.csr -subj "/CN=operator1/O=operators"
openssl x509 -req -in users/operator1.csr -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key -CAcreateserial -out users/operator1.crt -days 500

# 3. Пользователь из группы security (привилегированный - доступ к секретам)
openssl genrsa -out users/security1.key 2048
openssl req -new -key users/security1.key -out users/security1.csr -subj "/CN=security1/O=security"
openssl x509 -req -in users/security1.csr -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key -CAcreateserial -out users/security1.crt -days 500

# 4. Пользователь из группы auditors (привилегированный - аудит)
openssl genrsa -out users/auditor1.key 2048
openssl req -new -key users/auditor1.key -out users/auditor1.csr -subj "/CN=auditor1/O=auditors"
openssl x509 -req -in users/auditor1.csr -CA ~/.minikube/ca.crt -CAkey ~/.minikube/ca.key -CAcreateserial -out users/auditor1.crt -days 500

echo "Пользователи созданы:"
echo "1. viewer1 (группа: viewers) - только просмотр"
echo "2. operator1 (группа: operators) - настройка кластера"
echo "3. security1 (группа: security) - доступ к секретам"
echo "4. auditor1 (группа: auditors) - аудит кластера"
