#!/bin/bash
# port-forward-konga.sh - Exposes Konga UI on localhost:1337
# Usage: bash scripts/port-forward-konga.sh

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
NAMESPACE="lab-kong"
SERVICE="konga"
LOCAL_PORT="${1:-1337}"
kubectl config use-context kind-lab 2>/dev/null || true
if ! kubectl get svc "$SERVICE" -n "$NAMESPACE" &>/dev/null; then
  echo -e "${RED}[✗]${NC} Service $SERVICE not found. Apply konga/konga.yaml after starting Postgres and Kong."
  exit 1
fi

echo -e "${GREEN}[✓]${NC} Konga at http://localhost:$LOCAL_PORT"
echo -e "${YELLOW}[⚠]${NC} First access: create Konga admin user on registration screen."
echo -e "${BLUE}[INFO]${NC} Kong Admin API Connection (inside Konga):"
echo ""
kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" "$LOCAL_PORT:1337" --address 0.0.0.0
