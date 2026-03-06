# KServe Installation

This directory provides a helper script to install the core dependencies needed to run the KServe-based stack used by AIM. For production, you should manage and pin these dependencies yourself with your existing tooling. For quick testing, use the script below.

## Installation Modes

- **Minimal (Default)**: Installs only essential KServe components for basic model hosting
- **Full (`--enable=full`)**: Adds complete monitoring, autoscaling, and observability stack
- **Custom**: Mix and match components using `--enable` and `--skip` flags

## Requirements

- Kubernetes 1.24+ with `kubectl` configured
- Helm 3.8+
- Cluster admin privileges to install CRDs and cluster‑scoped resources
- Internet access to pull charts/manifests
- **Default Storage Class**: A storage class marked as default must be available for observability components (see [Storage Requirements](#storage-requirements) below)

Namespaces are created automatically when needed:

- `kserve-system`, `keda-system`, `kube-amd-gpu`, `kgateway-system`, `otel-lgtm-stack`

## Dependencies

### Core Components (Always Installed)

Prerequisites that are automatically installed if missing:
- cert-manager: `v1.18.2` (static manifest)
- Gateway API CRDs: `v1.2.1` (standard install)

### Minimal Mode Components (Default)

Essential components for basic model serving:
- KServe CRDs: `v0.15.2`
- KServe: `v0.15.2`

### Full Mode Additional Components (`--enable=full`)

Additional components for monitoring, scaling, and observability:
- KEDA: `2.17.2` (autoscaling)
- KGateway: `v2.1.0-main` (gateway components)
- OTEL LGTM Stack Standalone: `grafana/otel-lgtm` (observability)

### Observability Stack

The observability stack uses a standalone variant that bundles all observability components into a single pod for simplicity.

**`otel-lgtm-stack-standalone` (Standalone Variant - enabled with `--enable=full`)**
- A single container (image: `grafana/otel-lgtm`) bundling Grafana, Prometheus, Loki, Tempo
- Limited scalability (all components share one pod), ideal for development and testing
- Enabled implicitly by: `--enable=full` OR explicitly via `--enable=otel-lgtm-stack-standalone`

#### Example commands

Enable observability components only:
```bash
./install-deps.sh --enable=otel-lgtm-stack-standalone
```

Full mode (includes observability by default):
```bash
./install-deps.sh --enable=full
```

### Optional Components (Explicit Enable Required)

- AMD GPU Operator: `v1.3.0` (`--enable=amd-gpu-operator`)
- k6-operator: Load testing (`--enable=k6`)

## Storage Requirements

The observability stack component (`otel-lgtm-stack-standalone`) requires persistent storage for data retention. This component uses the cluster's **default storage class** or you can manually modify the storage class specifications in `post-helm/base/otel-lgtm-stack-standalone/otel-lgtm.yaml`.

**Quick Storage Setup:**

If your cluster doesn't have a default storage class, you can:

1. **Set an existing storage class as default:**
   ```bash
   kubectl patch storageclass <your-storage-class-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

2. **Or modify the configuration file:**
   - Edit `post-helm/base/otel-lgtm-stack-standalone/otel-lgtm.yaml`
   - Change `storageClassName: default` to your preferred storage class

For detailed storage requirements, configuration options, and production considerations, see the [Observability Stack Documentation](../docs/monitoring/observability-stack.md).

## Quick Installer (Testing)

Script path: `install-deps.sh`

### Installation Modes

The installer supports two main modes:

**Minimal Mode (Default)**
- Installs only the essential components needed to run KServe for model hosting
- Components: cert-manager, Gateway API CRDs, kserve-crd, kserve
- Use this for basic model serving without monitoring or advanced features

**Full Mode (`--enable=full`)**
- Installs the complete observability and scaling stack
- Includes all minimal components plus: autoscaling (keda), gateway (kgateway), observability (standalone lgtm by default)
- Use this for production-like environments with full monitoring and observability

### What it does:

1. **Preflight checks** and installs prerequisites if missing:
    - cert-manager `v1.18.2`
    - Gateway API CRDs `v1.2.1`

2. **Minimal Mode Components** (always installed):
    - `kserve-crd` (`oci://ghcr.io/kserve/charts/kserve-crd`, `kserve-system`)
    - `kserve` (`oci://ghcr.io/kserve/charts/kserve`, `kserve-system`)

3. **Full Mode Additional Components** (enabled with `--enable=full`):
    - `keda` (`kedacore/keda`, `keda-system`)
    - `kgateway` (gateway components, `kgateway-system`)
    - `otel-lgtm-stack-standalone` (Loki, Grafana, Tempo, Mimir single‑pod variant in `otel-lgtm-stack`)

4. **Optional Components** (require explicit enable):
    - `amd-gpu-operator` (`rocm/gpu-operator-charts`, `kube-amd-gpu`)
    - `k6` (k6-operator for load testing)

5. **Post-Helm kustomizations**:
    - Base configurations for each enabled component
    - AMD GPU overlay when GPU operator is enabled

Per‑component values live in: `helm-values/<component>.yaml`.

### Usage Examples

**Minimal installation (default)**:
```bash
# Minimal KServe installation - just model hosting capabilities
./install-deps.sh
```

**Full installation with monitoring and observability (standalone variant)**:
```bash
# Complete stack with monitoring, autoscaling, and observability (standalone)
./install-deps.sh --enable=full
```


**Adding specific components**:
```bash
# Minimal + just autoscaling
./install-deps.sh --enable=keda

# Full installation + AMD GPU support
./install-deps.sh --enable=full,amd-gpu-operator
```

**Excluding components from full installation**:
```bash
# Full installation but skip autoscaling
./install-deps.sh --enable=full --skip=keda

# Full installation but skip observability
./install-deps.sh --enable=full --skip=otel-lgtm-stack-standalone
```

### Important Notes

- **Component Dependencies**: If `kserve` is enabled, the script automatically enables `kserve-crd` to satisfy dependencies
- **Helm Repositories**: The script automatically sets up required Helm repos (`kedacore`, `rocm`, `grafana`)
- **Namespace Creation**: All required namespaces are created automatically during installation
- **Observability Variant Selection**: `--enable=full` includes the standalone observability stack.

## Production Guidance (Manual Management)

For production, we recommend managing these dependencies with your platform tooling (e.g., GitOps), using the versions above as a baseline. You can reuse the values from `helm-values/*.yaml` and adapt them to your environment, and apply your own post‑install manifests instead of the provided kustomizations.