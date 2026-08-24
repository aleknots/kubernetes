#!/bin/bash

# 1. Cria o namespace primeiro
echo "Criando namespace..."
kubectl apply -f namespace.yaml

# 2. Pequena pausa para o Kubernetes processar a criação
sleep 2

# 3. Aplica segredos e configurações
echo "Aplicando segredos e configurações..."
kubectl apply -f secrets/postgres-secrets.yaml
kubectl apply -f secrets/backstage-secrets.yaml
kubectl apply -f config/app-config.yaml

# 4. Aplica o banco de dados
echo "Iniciando Postgres..."
kubectl apply -f postgres/storage.yaml
kubectl apply -f postgres/deployment.yaml
kubectl apply -f postgres/service.yaml

# 5. Aplica o Backstage
echo "Iniciando Backstage..."
kubectl apply -f backstage/deployment.yaml
kubectl apply -f backstage/service.yaml

echo "Aguardando o pod do Backstage ficar Pronto..."
# Aguarda até que o pod com label app=backstage esteja pronto
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=120s

echo "Backstage online. Iniciando túnel em http://localhost:8081"
# Inicia o port-forward em segundo plano (&) e descarta logs
kubectl port-forward svc/backstage 8081:8081 -n backstage > /dev/null 2>&1 &

echo "Tudo pronto. Você pode acessar via navegador."
