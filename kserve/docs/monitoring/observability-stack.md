# Monitoring with OpenTelemetry + LGTM Stack

## Overview

The **OTel-LGTM stack** provides comprehensive observability for KServe deployments by combining **OpenTelemetry (OTel)** for telemetry data collection with the **LGTM stack** (Loki, Grafana, Tempo, Mimir) for storage, visualization, and analysis. This monitoring solution is automatically deployed when using the full KServe installation mode.

The observability stack uses a **standalone variant** that bundles all observability components into a single pod for simplicity and ease of deployment.

---

## Components

### 1. OpenTelemetry (OTel)

OpenTelemetry is a vendor-neutral, open-source observability framework for collecting telemetry data (logs, metrics, and traces) from applications.

- **OTel Collector**: A vendor-agnostic agent that receives, processes, and exports telemetry data.
- **OTel SDKs**: Language-specific libraries (e.g., for Go, Java, Python) used to instrument applications.
- **OTel Exporters**: Send data from the collector to backends like Loki, Tempo, or Mimir.

**In Kubernetes:**

- Deployed as a **DaemonSet** (for node-level collection), **Deployment** (for centralized collection), or **Sidecar** (for per-workload collection).
- Configured via a **ConfigMap** to define pipelines for processing and exporting data.

---

### 2. Loki (Logs)

Loki is a log aggregation system designed for efficiency and scalability, optimized for Kubernetes.

- Collects logs via **Promtail**, **Fluent Bit**, or **OTel Collector**.
- Stores logs in a time-series format.
- Integrates with Grafana for querying and visualization.

**In Kubernetes:**

- Loki is deployed as a **StatefulSet** or **Deployment**.
- **Promtail** is often deployed as a **DaemonSet** on each node to collect logs.

---

### 3. Grafana (Visualization)

Grafana is a powerful open-source analytics and monitoring platform.

- Visualizes metrics, logs, and traces from Mimir, Loki, and Tempo.
- Supports dashboards, alerts, and annotations.
- Integrates with OTel for trace and metric visualization.

**In Kubernetes:**

- Deployed as a **Deployment**.
- Configured with **ConfigMaps** and **Secrets** for data sources and dashboards.

---

### 4. Tempo (Traces)

Tempo is a distributed tracing backend by Grafana Labs.

- Stores and queries trace data.
- Integrates with OTel Collector for trace ingestion.
- Works with Grafana for trace visualization.

**In Kubernetes:**

- Deployed as a **StatefulSet** or **Deployment**.
- Can use object storage (e.g., Minio) for trace data.

---

### 5. Mimir (Metrics)

Mimir is a horizontally scalable, long-term storage backend for Prometheus metrics, providing Prometheus-compatible APIs.

- Collects metrics from applications and infrastructure via HTTP endpoints (Prometheus format).
- Stores metrics in a time-series database with long-term retention.
- Supports powerful querying with PromQL (Prometheus Query Language).
- Integrates with Grafana for visualization.
- Can be used for autoscaling decisions via HPA with custom metrics.

**In the standalone deployment:**

- Mimir is bundled within the single container alongside other LGTM components.
- Configured to scrape metrics from OTel collectors and KServe components.
- Provides Prometheus-compatible metrics API for autoscaling and alerting.

---

## Deployment in KServe

The monitoring stack is automatically installed when using the full KServe installation mode:

```bash
./install-deps.sh --enable=full
```

### Standalone Variant

The standalone variant uses a single container (`grafana/otel-lgtm`) that bundles all LGTM components:
- **All-in-one container**: Grafana, Mimir, Loki, Tempo in one pod
- **Quick setup**: Minimal resource requirements and fast startup
- **Broad compatibility**: Ideal for development, testing, CI environments, and smaller production deployments
- **Simplified management**: Single pod to monitor and maintain

You can also enable just the observability stack without other full-mode components:

```bash
./install-deps.sh --enable=otel-lgtm-stack-standalone
```

### Storage Requirements

The standalone observability stack requires persistent storage for data retention across pod restarts and upgrades.

#### Storage Access Patterns
- **Access Mode**: ReadWriteOnce (RWO) - all volumes are mounted to a single pod
- **Deployment Strategy**: Single replica with `Recreate` strategy (no concurrent pod access)
- **Storage Class Requirements**: Any storage class supporting RWO (most common type)
- **Network Storage**: Not required - local storage, EBS, or any RWO-capable storage works

#### Required Storage Volumes
- **Tempo**: 50Gi (distributed tracing data)
- **Loki Data**: 50Gi (log data)  
- **Loki Storage**: 50Gi (log index and metadata)
- **Grafana**: 10Gi (dashboard and configuration data)
- **Mimir**: 50Gi (metrics data)
- **Total**: ~220Gi

#### Storage Class Configuration

**Default Storage Class Usage:**
The deployment uses the cluster's **default storage class** (marked with `storageclass.kubernetes.io/is-default-class: "true"`). 

**If your cluster doesn't have a default storage class:**

1. **Check available storage classes:**
   ```bash
   kubectl get storageclass
   # Look for "(default)" in the output
   ```

2. **Set an existing storage class as default:**
   ```bash
   kubectl patch storageclass <your-storage-class-name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
   ```

3. **Or modify the configuration to use a specific storage class:**
   - Edit `post-helm/base/otel-lgtm-stack-standalone/otel-lgtm.yaml`
   - Change all instances of `storageClassName: default` to `storageClassName: <your-storage-class-name>`

**For production environments**, consider:
- Using high-performance storage classes for better observability performance  
- Configuring retention policies to manage storage usage
- Setting up storage monitoring and alerting
- Using separate storage classes for different components based on performance needs

### Production-Grade Alternative

For large-scale production environments requiring independent scaling, high availability, and advanced configuration options, consider deploying the LGTM components separately using their official Helm charts:

```bash
# Add the Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

- **Mimir**: [Production deployment with Helm](https://grafana.com/docs/helm-charts/mimir-distributed/latest/run-production-environment-with-helm/)
- **Loki**: [Installation with Helm](https://grafana.com/docs/loki/latest/setup/install/helm/)
- **Tempo**: [Kubernetes deployment with Helm](https://grafana.com/docs/tempo/latest/set-up-for-tracing/setup-tempo/deploy/kubernetes/helm-chart/)

This approach provides better resource isolation, independent scaling, and more granular configuration control compared to the standalone variant.

### Architecture Diagram

```
[AIM Inference Pods] --> [OTel SDKs] --> [OTel Collector] --> [Standalone LGTM Stack]
                                                                        |
                                                           [Loki | Tempo | Mimir | Grafana]
```

Installation includes:

- **OTel Collector**: Collects telemetry data from instrumented apps and forwards it to the LGTM stack.
- **Promtail**: Collects logs and forwards to Loki.
- **Standalone LGTM Stack**: Single-pod deployment containing Loki, Tempo, Mimir, and Grafana.
- **Grafana**: Central dashboard for visualization accessible via the bundled web interface.

## Collectors

The following collectors are deployed in the `otel-lgtm-stack` namespace as part of the installation:

### vllm-sidecar-collector
An OpenTelemetry Collector deployed as a sidecar to VLLM workloads. It scrapes Prometheus metrics from `localhost:8000/metrics`, enriches telemetry with workload metadata, and exports all data to the LGTM stack.

Add the annotation `sidecar.opentelemetry.io/inject: "otel-lgtm-stack/vllm-sidecar-collector"` to your inference workload to enable the sidecar.

### kgateway-collector
An OpenTelemetry Collector deployed as a standalone deployment to monitor KGateway components. It scrapes Prometheus metrics from both data plane (`kube-gateway` pods) and control plane (`kgateway` pods) in the `kgateway-system` namespace, and exports metrics to the LGTM stack.

### traces-collector-static
A standalone OpenTelemetry Collector deployed via static manifests to handle trace ingestion and export for the LGTM stack.

Defines the collector as a Kubernetes Deployment with support for OTLP, Jaeger, Zipkin, and Prometheus receivers. It exports traces to Tempo via OTLP gRPC. The collector also exposes health and telemetry endpoints.

### http-listener-tracing-policy
Configures KGateway's `kserve-gateway` to send OpenTelemetry traces to the collector. It sets up the tracing provider with service name `kgateway-http` and uses the collector's OTLP gRPC endpoint (`4317`) as the backend.

## Metrics and Dashboards

The monitoring stack collects comprehensive metrics from AIM inference workloads, including detailed vLLM metrics for model serving performance, request latency, throughput, and resource utilization.

For vLLM-specific metrics and Grafana dashboard examples, refer to the [vLLM metrics documentation](https://docs.vllm.ai/en/latest/design/metrics.html).

### Accessing Grafana

To view Grafana dashboards locally from your Kubernetes cluster, use `kubectl port-forward` to expose the Grafana service:

```bash
kubectl port-forward svc/lgtm-stack -n otel-lgtm-stack 3000:3000
```

Then access Grafana at `http://localhost:3000`.

## Related Documentation

- [KServe Installation Guide](../../kserve-install/) - Learn how to install with monitoring enabled
- [Sample Full Deployment](../../sample-full-aims-deployment/) - See monitoring in action with a complete example
- [Custom Models](../models/custom-models.md) - Configure monitoring for your custom models

## Resources

- [OpenTelemetry](https://opentelemetry.io/)
- [Grafana Loki](https://grafana.com/oss/loki/)
- [Grafana Tempo](https://grafana.com/oss/tempo/)
- [Grafana Mimir](https://grafana.com/oss/mimir/)
- [Grafana](https://grafana.com/)