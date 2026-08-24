#!/bin/bash
# Provisiona o lab padrão: Kind + Postgres + Kong Manager OSS + site de demonstração.
# Uso: bash scripts/install-base.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="lab"

cd "$ROOT"

echo "=== Kind Cluster ==="
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[!] Cluster '$CLUSTER_NAME' já existe; reutilizando."
else
  kind create cluster --config cluster.yaml
fi

kind export kubeconfig --name "$CLUSTER_NAME"
kubectl config use-context "kind-${CLUSTER_NAME}"
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl label node lab-worker node-role.kubernetes.io/worker=worker --overwrite 2>/dev/null || true
kubectl label node lab-worker2 node-role.kubernetes.io/worker=worker --overwrite 2>/dev/null || true

ensure_kong_crds() {
  local marker="kongplugins.configuration.konghq.com"

  if kubectl get crd "$marker" &>/dev/null; then
    echo "[*] CRDs do Kong já presentes no cluster."
    return 0
  fi

  echo "[*] CRDs do Kong ausentes; instalando a partir do chart kong/kong..."
  if helm show crds kong/kong 2>/dev/null | kubectl apply -f -; then
    echo "[v] CRDs aplicadas via helm show crds."
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  helm pull kong/kong --untar -d "$tmp"
  kubectl apply -f "$tmp/kong/crds/"
  echo "[v] CRDs aplicadas via helm pull."
}

echo "=== Imagens ==="
for image in \
  postgres:11-alpine \
  kong:3.8.0 \
  kong/kubernetes-ingress-controller:3.2.1 \
  nginx:alpine; do
  docker pull "$image"
done

echo "=== Namespaces ==="
kubectl apply -f namespaces.yaml

echo "=== PostgreSQL (Kong) ==="
kubectl apply -f postgres/secret.yaml
kubectl apply -f postgres/deployment.yaml
kubectl wait --for=condition=Ready pod -l app=postgres -n lab-kong --timeout=180s

echo "=== Kong CRDs + Helm (Gateway + Manager OSS + KIC) ==="
helm repo add kong https://charts.konghq.com 2>/dev/null || true
helm repo update

ensure_kong_crds

# --skip-crds: CRDs já existem sem metadados de release do Helm.
helm upgrade --install kong kong/kong \
  --namespace lab-kong \
  --create-namespace \
  --values kong/values.yaml \
  --skip-crds \
  --wait \
  --timeout 8m

kubectl rollout status deployment/kong-kong -n lab-kong --timeout=600s

echo "=== Proxy Autenticado do Kong Manager ==="
kubectl apply -f manager-auth/
kubectl rollout status deployment/kong-manager-auth -n lab-kong --timeout=120s

echo "=== Plugins e Apps de Exemplo ==="
# Limpa a rota de demonstração /admin de versões anteriores do lab ao reutilizar o cluster.
kubectl delete \
  deployment/admin-site \
  service/admin-site-service \
  ingress/admin-site-ingress \
  configmap/admin-site-html \
  kongplugin/admin-basic-auth \
  kongconsumer/admin-user \
  secret/admin-user-basic-auth \
  --namespace lab-app \
  --ignore-not-found
kubectl apply -f kong/rate-limit.yaml
kubectl apply -f apps/public-site/
kubectl wait --for=condition=Ready pod -l app=public-site -n lab-app --timeout=120s

echo ""
echo "[v] Base stack ready."
echo "    Site:     bash scripts/port-forward-site.sh"
echo "    Manager:  bash scripts/port-forward-manager.sh"
