#!/bin/bash

# 1. Create namespace first
echo "Creating namespace..."
kubectl apply -f namespace.yaml

# 2. Short pause for Kubernetes to process creation
sleep 2

# 3. Apply secrets and configurations
echo "Applying secrets and configurations..."
kubectl apply -f secrets/postgres-secrets.yaml
kubectl apply -f secrets/backstage-secrets.yaml
kubectl apply -f config/app-config.yaml

# 4. Apply database
echo "Starting Postgres..."
kubectl apply -f postgres/storage.yaml
kubectl apply -f postgres/deployment.yaml
kubectl apply -f postgres/service.yaml

# 5. Apply Backstage
echo "Starting Backstage..."
kubectl apply -f backstage/deployment.yaml
kubectl apply -f backstage/service.yaml

echo "Waiting for Backstage pod to become Ready..."
# Wait until pod with label app=backstage is ready
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=120s

echo "Backstage is online. Starting tunnel at http://localhost:8081"
# Start port-forward in background (&) and discard logs
kubectl port-forward svc/backstage 8081:8081 -n backstage > /dev/null 2>&1 &

echo "All ready. You can access via browser."
