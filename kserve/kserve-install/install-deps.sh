#!/usr/bin/env bash
# Ensure we are running under bash even if invoked with sh
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi
set -euo pipefail

# Installs Helm dependencies individually using `helm upgrade --install`.
# Modes:
#   - Minimal (default): Minimal KServe installation (kserve-crd, kserve, cert-manager, Gateway API)
#   - Full: Full installation with monitoring, scaling, and observability components
# 
# Use --enable=full for full installation, --enable=<name> and/or --skip=<name> to toggle individual components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_DIR="${SCRIPT_DIR}/helm-values"

usage() {
  cat <<EOF
Usage: $0 [--enable=<name>[,name2]] [--skip=<name>[,name2]]

Installation Modes:
  Default (Minimal):  Minimal KServe installation for hosting models
                     - cert-manager, Gateway API, kserve-crd, kserve
  --enable=full: Full installation with monitoring and observability
                     - Includes all minimal components plus: keda, kgateway, lgtm-stack

Components (release names):
  Minimal mode:
    - kserve-crd      (KServe Custom Resource Definitions)
    - kserve          (KServe core components)
  
  Full mode additional (enabled with --enable=full):
    - keda            (Kubernetes Event-driven Autoscaling)
    - kgateway        (Gateway components)
    - otel-lgtm-stack-standalone (Loki, Grafana, Tempo, Mimir - observability)
  
  Optional components (always require explicit enable):
    - amd-gpu-operator (AMD GPU support)
    - k6              (k6-operator for load testing)

Examples:
  $0                                              # minimal mode (minimal KServe)
  $0 --enable=full                            # full mode (all components)
  $0 --enable=full,amd-gpu-operator           # full mode + AMD GPU support
  $0 --enable=full --skip=keda                # full mode but skip KEDA
  $0 --enable=keda                                 # minimal mode + autoscaling only
EOF
}

split_csv() {
  local IFS=","; read -r -a _out <<< "$1"; printf '%s\n' "${_out[@]}";
}

# Default enablement for minimal mode: only KServe essentials
ENABLE_KSERVE_CRD=1
ENABLE_KSERVE=1
ENABLE_KEDA=0
ENABLE_AMD_GPU_OPERATOR=0
ENABLE_K6=0
ENABLE_KGATEWAY_CRD=0
ENABLE_KGATEWAY=0
ENABLE_OTEL_LGTM_STACK_STANDALONE=0

# Track if full mode was enabled (for display purposes)
FULL_MODE_ENABLED=0

# Set defaults for full mode
set_full_defaults() {
  FULL_MODE_ENABLED=1
  ENABLE_KEDA=1
  ENABLE_KGATEWAY_CRD=1
  ENABLE_KGATEWAY=1
  ENABLE_OTEL_LGTM_STACK_STANDALONE=1
  # Note: amd-gpu-operator and k6 remain disabled by default even in full mode
}

set_flag() {
  local name="$1" value="$2"
  case "$name" in
    kserve-crd) ENABLE_KSERVE_CRD="$value" ;;
    kserve) ENABLE_KSERVE="$value" ;;
    keda) ENABLE_KEDA="$value" ;;
    amd-gpu-operator) ENABLE_AMD_GPU_OPERATOR="$value" ;;
    k6) ENABLE_K6="$value" ;;
    kgateway-crd) ENABLE_KGATEWAY_CRD="$value" ;;
    kgateway) ENABLE_KGATEWAY="$value" ;;
    otel-lgtm-stack-standalone) ENABLE_OTEL_LGTM_STACK_STANDALONE="$value" ;;
    full) 
      if [[ "$value" -eq 1 ]]; then
        set_full_defaults
      fi
      ;;
    *) echo "Unknown component: $name" >&2; exit 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable=*)
      v="${1#*=}"; shift
      for name in $(split_csv "$v"); do
        [[ -z "$name" ]] && continue
        set_flag "$name" 1
      done
      ;;
    --skip=*)
      v="${1#*=}"; shift
      for name in $(split_csv "$v"); do
        [[ -z "$name" ]] && continue
        set_flag "$name" 0
      done
      ;;
    -h|--help)
      usage; exit 0;
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage; exit 1;
      ;;
  esac
done

# Preflight
echo "==> Checking prerequisites"

# cert-manager: check CRD as proxy for install; install if missing
if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  echo "- Installing cert-manager (v1.18.2)"
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml
  echo "  Waiting for cert-manager deployments to be ready..."
  kubectl -n cert-manager rollout status deploy/cert-manager --timeout=180s || true
  kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=180s || true
  kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=180s || true
else
  echo "- cert-manager already installed"
fi

# Gateway API: check a representative CRD
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  echo "- Installing Gateway API CRDs (v1.2.1 standard-install)"
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
else
  echo "- Gateway API CRDs already installed"
fi

#if ! kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
#  echo "- Installing KEDA CRDs"
#  kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.17.2/keda-2.17.2-crds.yaml --server-side
#else
#  echo "- KEDA CRDs already installed"
#fi


# Ensure CRDs are installed if KServe itself is enabled
if [[ "$ENABLE_KSERVE" -eq 1 && "$ENABLE_KSERVE_CRD" -eq 0 ]]; then
  echo "Note: Enabling kserve-crd because kserve is enabled."
  ENABLE_KSERVE_CRD=1
fi

# Display installation mode
if [[ "$FULL_MODE_ENABLED" -eq 1 ]]; then
  echo "==> Running in FULL mode - installing full observability stack"
else
  echo "==> Running in MINIMAL mode - installing minimal KServe components"
  echo "    Use --enable=full for full installation with monitoring and observability"
fi

echo "==> Preparing Helm repositories"
if [[ "$ENABLE_KEDA" -eq 1 ]]; then
  helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1 || true
fi
if [[ "$ENABLE_AMD_GPU_OPERATOR" -eq 1 ]]; then
  helm repo add rocm https://rocm.github.io/gpu-operator >/dev/null 2>&1 || true
fi
if [[ "$ENABLE_K6" -eq 1 ]]; then
  helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
fi
helm repo update >/dev/null

echo "==> Installing/Upgrading components"

# Install KEDA first - it must be available before KServe for autoscaling support
if [[ "$ENABLE_KEDA" -eq 1 ]]; then
  echo "- Applying keda in namespace keda-system"
  helm upgrade --install keda kedacore/keda \
    --namespace keda-system \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version 2.17.2 \
    -f "${VALUES_DIR}/keda.yaml"
else
  echo "- Skipping keda"
fi

# Install KServe CRDs before KServe controller
if [[ "$ENABLE_KSERVE_CRD" -eq 1 ]]; then
  echo "- Applying kserve-crd in namespace kserve-system"
  helm upgrade --install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd \
    --namespace kserve-system \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version v0.15.2 \
    -f "${VALUES_DIR}/kserve-crd.yaml"
else
  echo "- Skipping kserve-crd"
fi

if [[ "$ENABLE_KSERVE" -eq 1 ]]; then
  echo "- Applying kserve in namespace kserve-system"
  helm upgrade --install kserve oci://ghcr.io/kserve/charts/kserve \
    --namespace kserve-system \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version v0.15.2 \
    -f "${VALUES_DIR}/kserve.yaml"
else
  echo "- Skipping kserve"
fi

if [[ "$ENABLE_AMD_GPU_OPERATOR" -eq 1 ]]; then
  echo "- Applying amd-gpu-operator in namespace kube-amd-gpu"
  helm upgrade --install amd-gpu-operator rocm/gpu-operator-charts \
    --namespace kube-amd-gpu \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version v1.3.0 \
    -f "${VALUES_DIR}/amd-gpu-operator.yaml"
else
  echo "- Skipping amd-gpu-operator"
fi

if [[ "$ENABLE_K6" -eq 1 ]]; then
  # This is broken at the moment
  echo "K6 installation via this script is broken at the moment, skipping"
#  echo "- Applying k6 (k6-operator) in namespace k6-operator-system"
#  helm upgrade --install k6 grafana/k6-operator \
#    --namespace k6-operator-system \
#    --create-namespace \
#    --wait \
#    --timeout 10m
else
  echo "- Skipping k6 (k6-operator)"
fi

if [[ "$ENABLE_KGATEWAY_CRD" -eq 1 ]]; then
  echo "- Applying kgateway-crd in namespace kgateway-system"
  helm upgrade --install kgateway-crd oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds \
    --namespace kgateway-system \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version v2.1.0-main
else
  echo "- Skipping kgateway-crd"
fi

if [[ "$ENABLE_KGATEWAY" -eq 1 ]]; then
  echo "- Applying kgateway in namespace kgateway-system"
  helm upgrade --install kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway \
    --namespace kgateway-system \
    --create-namespace \
    --wait \
    --timeout 10m \
    --version v2.1.0-main \
    -f "${VALUES_DIR}/kgateway.yaml"
else
  echo "- Skipping kgateway"
fi

if [[ "$ENABLE_OTEL_LGTM_STACK_STANDALONE" -eq 1 ]]; then
  echo "- Creating namespace otel-lgtm-stack"
  kubectl create namespace otel-lgtm-stack || true

  echo "- Applying otel-operator in namespace otel-operator"
  kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.136.0/opentelemetry-operator.yaml

  echo "- Creating namespace promtail"
  kubectl create namespace promtail || true
else
  echo "- Skipping otel-lgtm-stack-standalone"
fi



echo "==> Applying post-Helm kustomizations"

# Apply kustomizations for each enabled component individually
POST_HELM_BASE_DIR="${SCRIPT_DIR}/post-helm/base"

# Always apply KServe components if enabled
if [[ "$ENABLE_KSERVE" -eq 1 ]]; then
  if [[ -d "${POST_HELM_BASE_DIR}/kserve" ]]; then
    echo "- Applying KServe post-helm configuration"
    
    # Determine base path (base or AMD GPU overlay)
    KSERVE_BASE_PATH="${POST_HELM_BASE_DIR}/kserve"
    if [[ "$ENABLE_AMD_GPU_OPERATOR" -eq 1 && -d "${SCRIPT_DIR}/post-helm/overlays/amd-gpu-operator" ]]; then
      KSERVE_BASE_PATH="${SCRIPT_DIR}/post-helm/overlays/amd-gpu-operator"
      echo "  Using AMD GPU operator overlay"
    fi
    
    kubectl apply -k "$KSERVE_BASE_PATH"
  fi
fi


# Apply KGateway components if enabled
if [[ "$ENABLE_KGATEWAY" -eq 1 ]]; then
  if [[ -d "${POST_HELM_BASE_DIR}/kgateway" ]]; then
    echo "- Applying KGateway post-helm configuration"
    kubectl apply -k "${POST_HELM_BASE_DIR}/kgateway"
  fi
fi

# Apply OTEL LGTM STANDALONE stack components if enabled
if [[ "$ENABLE_OTEL_LGTM_STACK_STANDALONE" -eq 1 ]]; then
  if [[ -d "${POST_HELM_BASE_DIR}/otel-lgtm-stack-standalone" ]]; then
    echo "- Applying OTEL LGTM STANDALONE stack post-helm configuration"
    kubectl apply -k "${POST_HELM_BASE_DIR}/otel-lgtm-stack-standalone"
  fi
fi

# Apply OTEL collectors if OTEL stack is enabled
if [[ "$ENABLE_OTEL_LGTM_STACK_STANDALONE" -eq 1 ]]; then
  if [[ -d "${POST_HELM_BASE_DIR}/otel-collectors" ]]; then
    echo "- Applying OTEL collectors post-helm configuration"
    kubectl apply -k "${POST_HELM_BASE_DIR}/otel-collectors"
    echo "- Applying Promtail post-helm configuration" 
    kubectl apply -k "${POST_HELM_BASE_DIR}/promtail"
  fi
fi

if [[ "$FULL_MODE_ENABLED" -eq 1 ]]; then
  echo "==> FULL installation completed"
  echo "    Installed: KServe + autoscaling (KEDA) + gateway + observability"
else
  echo "==> MINIMAL installation completed"
  echo "    Installed: Minimal KServe components for model hosting"
  echo "    To add monitoring and observability, run with --enable=full"
fi

echo "==> Done"
