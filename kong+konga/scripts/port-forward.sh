#!/bin/bash
# port-forward.sh - Script to simplify Kong port-forwarding
# Usage: bash scripts/port-forward.sh

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
    log_info "Starting port-forward for Kong..."
    echo ""

    kubectl config use-context kind-lab 2>/dev/null || log_warning "Context kind-lab not found; using current context"

    # Verify if service exists
    if ! kubectl get svc "$SERVICE" -n "$NAMESPACE" > /dev/null 2>&1; then
        log_error "Service '$SERVICE' not found in namespace '$NAMESPACE'"
        log_warning "Ensure Kong has been installed correctly"
        exit 1
    fi

    log_success "Service found: $NAMESPACE/$SERVICE"
    echo ""

    log_warning "Port-forward started:"
    echo "  Local: $ADDRESS:$LOCAL_PORT"
    echo "  Remote: $SERVICE:$REMOTE_PORT (namespace: $NAMESPACE)"
    echo ""
    echo "Kong will be available at: http://localhost:$LOCAL_PORT/site and http://localhost:$LOCAL_PORT/admin"
    echo ""
    log_info "Press CTRL+C to stop port-forward"
    echo ""

    # Execute port-forward
    kubectl port-forward \
        -n "$NAMESPACE" \
        "svc/$SERVICE" \
        "$LOCAL_PORT:$REMOTE_PORT" \
        --address "$ADDRESS"
}

# Run main
main "$@"
