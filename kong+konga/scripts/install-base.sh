#!/bin/bash
# Provisions legacy lab: Kind + Postgres + Kong + Konga + demo sites.
# Usage: bash scripts/install-base.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="lab"

cd "$ROOT"

echo "=== Kind Cluster ==="
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "[!] Cluster '$CLUSTER_NAME' already exists; reusing."
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
    echo "[*] Kong CRDs already present in cluster."
    return 0
  fi

  echo "[*] Kong CRDs missing; installing from kong/kong chart..."
  if helm show crds kong/kong 2>/dev/null | kubectl apply -f -; then
    echo "[v] CRDs applied via helm show crds."
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  helm pull kong/kong --untar -d "$tmp"
  kubectl apply -f "$tmp/kong/crds/"
  echo "[v] CRDs applied via helm pull."
}

echo "=== Images ==="
for image in \
  postgres:11-alpine \
  kong:3.4.2 \
  kong/kubernetes-ingress-controller:3.2.1 \
  pantsel/konga:0.14.9 \
  nginx:alpine; do
  docker pull "$image"
done

echo "=== Namespaces ==="
kubectl apply -f namespaces.yaml

echo "=== PostgreSQL (Kong + Konga) ==="
kubectl apply -f konga/secret.yaml
kubectl apply -f konga/postgres-init.yaml
kubectl apply -f konga/postgres.yaml
kubectl wait --for=condition=Ready pod -l app=postgres -n lab-kong --timeout=180s

echo "=== Kong CRDs + Helm (Gateway + KIC) ==="
helm repo add kong https://charts.konghq.com 2>/dev/null || true
helm repo update

ensure_kong_crds

# --skip-crds: CRDs already exist without Helm release metadata.
helm upgrade --install kong kong/kong \
  --namespace lab-kong \
  --create-namespace \
  --values kong/values.yaml \
  --skip-crds \
  --wait \
  --timeout 8m

kubectl rollout status deployment/kong-kong -n lab-kong --timeout=600s

echo "=== Konga ==="
kubectl apply -f konga/konga.yaml
kubectl wait --for=condition=Ready pod -l app=konga -n lab-kong --timeout=300s

echo "=== Example Plugins & Apps ==="
kubectl apply -f kong/rate-limit.yaml
kubectl apply -f kong/basic-auth.yaml
kubectl apply -f apps/public-site/
kubectl apply -f apps/admin-site/
kubectl wait --for=condition=Ready pod -l app=public-site -n lab-app --timeout=120s
kubectl wait --for=condition=Ready pod -l app=admin-site -n lab-app --timeout=120s

echo ""
echo "[v] Base stack ready."
echo "    Site:   bash scripts/port-forward.sh"
echo "    Konga:  bash scripts/port-forward-konga.sh"
