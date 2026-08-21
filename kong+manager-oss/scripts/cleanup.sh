#!/bin/bash
# cleanup.sh - Removes the lab Kind cluster
# Usage: bash scripts/cleanup.sh [--yes]

CLUSTER_NAME="lab"
FORCE=false
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && FORCE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }

if ! $FORCE; then
  log_warn "This will delete the Kind cluster '$CLUSTER_NAME'."
  read -r -p "Type 'yes' to confirm: " r
  [[ "$r" == "yes" ]] || { log_info "Cancelled."; exit 0; }
fi

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "$CLUSTER_NAME"
  log_ok "Cluster removed"
else
  log_warn "Cluster '$CLUSTER_NAME' not found"
fi

log_info "kubectl context: kind delete cluster removes kind-lab from ~/.kube/config"
log_info "Check: kind get clusters"
