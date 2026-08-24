#!/bin/bash
# cleanup.sh - Remove o cluster Kind do lab
# Uso: bash scripts/cleanup.sh [--yes]

CLUSTER_NAME="lab"
FORCE=false
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && FORCE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }

if ! $FORCE; then
  log_warn "Isso excluirá o cluster Kind '$CLUSTER_NAME'."
  read -r -p "Digite 'yes' para confirmar: " r
  [[ "$r" == "yes" ]] || { log_info "Cancelado."; exit 0; }
fi

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "$CLUSTER_NAME"
  log_ok "Cluster removido"
else
  log_warn "Cluster '$CLUSTER_NAME' não encontrado"
fi

log_info "Contexto do kubectl: kind delete cluster remove kind-lab do ~/.kube/config"
log_info "Verificar: kind get clusters"
