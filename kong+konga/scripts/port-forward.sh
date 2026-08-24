#!/bin/bash
# port-forward.sh - Script para simplificar o port-forwarding do Kong
# Uso: bash scripts/port-forward.sh

# Cores para saída
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sem Cor

NAMESPACE="lab-kong"
SERVICE="kong-kong-proxy"
LOCAL_PORT="${1:-8000}"
REMOTE_PORT="80"
ADDRESS="0.0.0.0"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

main() {
    log_info "Iniciando port-forward para o Kong..."
    echo ""

    kubectl config use-context kind-lab 2>/dev/null || log_warning "Contexto kind-lab não encontrado; utilizando contexto atual"

    # Verifica se o serviço existe
    if ! kubectl get svc "$SERVICE" -n "$NAMESPACE" > /dev/null 2>&1; then
        log_error "Serviço '$SERVICE' não encontrado no namespace '$NAMESPACE'"
        log_warning "Certifique-se de que o Kong foi instalado corretamente"
        exit 1
    fi

    log_success "Serviço encontrado: $NAMESPACE/$SERVICE"
    echo ""

    log_warning "Port-forward iniciado:"
    echo "  Local: $ADDRESS:$LOCAL_PORT"
    echo "  Remoto: $SERVICE:$REMOTE_PORT (namespace: $NAMESPACE)"
    echo ""
    echo "O Kong estará disponível em: http://localhost:$LOCAL_PORT/site e http://localhost:$LOCAL_PORT/admin"
    echo ""
    log_info "Pressione CTRL+C para parar o port-forward"
    echo ""

    # Executa o port-forward
    kubectl port-forward \
        -n "$NAMESPACE" \
        "svc/$SERVICE" \
        "$LOCAL_PORT:$REMOTE_PORT" \
        --address "$ADDRESS"
}

# Executa o main
main "$@"
