# KServe Components

This directory contains different KServe implementations and examples for AIM (AMD Inference Microservices).

## Directory Structure

### [kserve-install/](./kserve-install/)
Installation scripts and documentation for setting up the complete KServe stack with all required dependencies.

- Core KServe installation
- Dependencies (cert-manager, KEDA, monitoring stack, etc.)
- Installation helper scripts
- Prerequisites and requirements

### [sample-minimal-aims-deployment/](./sample-minimal-aims-deployment/)
Basic AIM deployment example with essential components:

- **Qwen3 32B model** using pre-built container
- **ClusterServingRuntime** configuration for AIM containers
- **InferenceService** with minimal resource allocation
- Simple two-file deployment for getting started quickly

### [sample-full-aims-deployment/](./sample-full-aims-deployment/)
Complete production-ready AIM deployment example featuring:

- **Llama 3.1 8B Instruct model** with PVC-based model caching
- **ClusterServingRuntime** configuration for AIM containers
- **InferenceService** with autoscaling and tracing
- **KGateway routing** for traffic management
- **Model downloading** automation via Kubernetes Job
- Ready-to-deploy YAML manifests for immediate use

### [docs/](./docs/)
Additional KServe documentation and guides:

- [Custom Models](./docs/models/custom-models.md) - Creating and deploying custom model configurations
- [Model Caching](./docs/models/model-caching.md) - PVC-based model caching for improved performance
- [Observability Stack](./docs/monitoring/observability-stack.md) - OpenTelemetry + LGTM stack for comprehensive monitoring

## Getting Started

1. **Installation**: Start with [kserve-install/](./kserve-install/) to set up your cluster
2. **Basic Example**: Use [sample-minimal-aims-deployment/](./sample-minimal-aims-deployment/) for a basic inference service
3. **Production Example**: Deploy [sample-full-aims-deployment/](./sample-full-aims-deployment/) for a production-ready configuration
4. **Additional Guides**: Browse [docs/](./docs/) for specific topics and advanced configurations

## Prerequisites

- Kubernetes 1.24+ with `kubectl` configured
- Helm 3.8+
- Cluster admin privileges
- Internet access for pulling charts and manifests
