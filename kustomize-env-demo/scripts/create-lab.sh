#!/usr/bin/env bash
# Cria o cluster kind, instala o Argo CD e aplica o padrão App-of-Apps.
# Uso (a partir da raiz do repo): kustomize-env-demo/scripts/create-lab.sh
set -euo pipefail
CLUSTER="${CLUSTER_NAME:-kustomize-demo}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Criando cluster kind '$CLUSTER'..."
  kind create cluster --name "$CLUSTER"
fi

kubectl config use-context "kind-${CLUSTER}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo "Instalando o Argo CD..."
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aplicações usam spec.project: lab - O AppProject precisa existir primeiro.
kubectl apply -f "$ROOT/argocd/appproject-lab.yaml"

# Consulta o Git a cada 60s (o padrão de consulta do Argo CD é 180s).
kubectl -n argocd patch cm argocd-cm --type merge -p '{"data":{"timeout.reconciliation":"60s"}}'
kubectl -n argocd rollout restart statefulset/argocd-application-controller

echo "Aguardando o Argo CD ficar pronto..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "Aplicando Aplicação Raiz (App-of-Apps)..."
kubectl apply -f "$ROOT/argocd/app-root.yaml"

# Carrega variáveis de ambiente do .env se presente
if [[ -f "$ROOT/.env" ]]; then
  # export variables from .env
  set -a
  source "$ROOT/.env"
  set +a
fi

if [[ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]]; then
  echo "Configuring Cloudflare Tunnel in cluster..."
  kubectl create secret generic cloudflared-token \
    -n kube-system \
    --from-literal=token="$CLOUDFLARE_TUNNEL_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "$ROOT/cloudflare/cloudflared.yaml"
fi

echo ""
echo "=========================================="
echo "Lab created successfully!"
echo "=========================================="
echo "Initial Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo ""
echo "Access via Cloudflare Tunnel (if configured):"
echo "  - https://dev.company.cloud"
echo "  - https://stg.company.cloud"
echo "  - https://prd.company.cloud"
echo "  - https://argocd.company.cloud"
echo ""
echo "Or via local Port-Forward:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8088:443"
echo "  URL: https://localhost:8088 (User: admin)"
echo "=========================================="
