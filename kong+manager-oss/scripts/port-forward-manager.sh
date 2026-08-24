#!/bin/bash
# Expõe o proxy autenticado do Kong Manager OSS para o navegador local.
# Uso: bash scripts/port-forward-manager.sh [porta_manager]

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="lab-kong"
MANAGER_SERVICE="kong-manager-auth"
MANAGER_LOCAL_PORT="${1:-8002}"

kubectl config use-context kind-lab 2>/dev/null || true

if ! kubectl get svc "$MANAGER_SERVICE" -n "$NAMESPACE" &>/dev/null; then
  echo -e "${RED}[x]${NC} Service $MANAGER_SERVICE not found."
  echo -e "${YELLOW}[!]${NC} Run install-base.sh or apply manager-auth/ after Helm Kong."
  exit 1
fi

echo -e "${GREEN}[v]${NC} Kong Manager OSS: http://localhost:$MANAGER_LOCAL_PORT/manager/"
echo -e "${YELLOW}[!]${NC} Lab credentials: admin / admin123"
echo ""

kubectl port-forward -n "$NAMESPACE" "svc/$MANAGER_SERVICE" "$MANAGER_LOCAL_PORT:8002" --address 0.0.0.0
