#!/usr/bin/env bash
# Deletes lab Applications/namespaces (if kind cluster exists) and deletes kind cluster.
# Usage (from repo root): kustomize-env-demo/scripts/delete-lab.sh [--yes]
set -euo pipefail

CLUSTER="${CLUSTER_NAME:-kustomize-demo}"
CONTEXT="kind-${CLUSTER}"
FORCE=false
[[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && FORCE=true

if ! $FORCE; then
  echo "This will delete Argo CD, app-banner-* namespaces, and kind cluster '${CLUSTER}'."
  read -r -p "Type 'yes' to confirm: " reply
  [[ "${reply}" == "yes" ]] || { echo "Cancelled."; exit 0; }
fi

echo "Stop active port-forwards (Ctrl+C) if currently running."

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER}"; then
  kubectl config use-context "${CONTEXT}" >/dev/null 2>&1 || true
  if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    kubectl -n argocd delete application app-banner-root --ignore-not-found
    kubectl -n argocd delete application app-banner-dev app-banner-stg app-banner-prd --ignore-not-found
    kubectl -n argocd delete applicationset app-banner --ignore-not-found
    kubectl -n argocd delete appproject lab --ignore-not-found
    kubectl delete ns app-banner-dev app-banner-stg app-banner-prd --ignore-not-found
  fi
  kind delete cluster --name "${CLUSTER}"
  echo "Cluster '${CLUSTER}' removed."
else
  echo "Cluster '${CLUSTER}' not found."
fi

echo "Check: kind get clusters"
kind get clusters 2>/dev/null || true
