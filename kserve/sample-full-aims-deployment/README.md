# Sample: AIM Llama 3.1 8B Instruct Deployment with PVC Model Cache

This folder contains a complete example showing how to:

1. Provision a PersistentVolumeClaim (PVC) for a shared model cache
2. Download the Meta Llama 3.1 8B Instruct FP8 KV model into the PVC
3. Define a ClusterServingRuntime for AIM
4. Deploy an InferenceService that serves the model with autoscaling & tracing
5. Expose the predictor via Gateway API HTTPRoute

## Files

- [`model-store-pvc.yaml`](./model-store-pvc.yaml) – RWX PVC used as a shared model store
- [`download-aim-llama-3.1-8b.yaml`](./download-aim-llama-3.1-8b.yaml) – Kubernetes Job that downloads the model into the PVC
- [`servingruntime-aim-llama-3.1-8b.yaml`](./servingruntime-aim-llama-3.1-8b.yaml) – ClusterServingRuntime defining the AIM container image
- [`aim-llama-3.1-8b-instruct.yaml`](./aim-llama-3.1-8b-instruct.yaml) – InferenceService referencing the runtime and mounting the PVC
- [`http-route-aim-llama-3-1-8b-instruct.yaml`](./http-route-aim-llama-3-1-8b-instruct.yaml) – HTTPRoute exposing the predictor service at path prefix `/aim-llama-3-1-8b-instruct` (prefix rewritten to `/` for backend)
- [`model-caching.md`](../docs/models/model-caching.md) – Additional background on PVC-based model caching

## Prerequisites

Before deploying, you need a Hugging Face token to download the model:

1. Get your token from https://huggingface.co/settings/tokens
2. Update [`./secret/hf-token-secret.yaml`](./secret/hf-token-secret.yaml) with your base64-encoded token:
   ```bash
   echo -n "hf_your_actual_token" | base64
   ```
3. Replace the placeholder in the secret YAML file

### Step 0. Create the Hugging Face Token Secret
First, create the secret required for model download:
```bash
kubectl apply -f ./secret/hf-token-secret.yaml
```

## Workflow
We recommend following the step-by-step deployment below to ensure the model download is completed before the inference service is deployed. 

Alternatively, you can deploy everything at once with:
   ```bash
   kubectl apply -f ./kserve/sample-full-aims-deployment/
   ```
   However, this may cause the unexpected behaviour if the model download hasn't finished yet.
   
### Step-by-Step Deployment

### 1. Create the PVC
Apply the PVC manifest to allocate storage (200Gi, RWX):
```bash
kubectl apply -f model-store-pvc.yaml
```

### 2. Download the Model to the PVC
Run the download Job. It installs the Hugging Face CLI and pulls the model into the path `/pv/amd/Llama-3.1-8B-Instruct-FP8-KV` on the PVC. Path pattern `org/model` (here `amd/Llama-3.1-8B-Instruct-FP8-KV`) is important for AIM model discovery.
```bash
kubectl apply -f download-aim-llama-3.1-8b.yaml
```
Monitor:
```bash
kubectl get jobs
kubectl logs job/model-downloader-meta-llama-3-1--8b
```

### 3. Install the Serving Runtime
Defines the container image and ports used by AIM:
```bash
kubectl apply -f servingruntime-aim-llama-3.1-8b.yaml
```

### 4. Deploy the Inference Service
Mounts the PVC using `storageUri: pvc://model-store-pvc/` and expects the model to be under `/mnt/models/amd/Llama-3.1-8B-Instruct-FP8-KV/` inside the container:
```bash
kubectl apply -f aim-llama-3.1-8b-instruct.yaml
```
Check status:
```bash
kubectl describe inferenceservice aim-llama-3-1-8b-instruct
kubectl logs deployment/aim-llama-3-1-8b-instruct-predictor
```

### 5. Expose via HTTPRoute (Gateway API)
Apply the HTTPRoute manifest to make the predictor reachable through the `kserve-gateway` with a path prefix:
```bash
kubectl apply -f http-route-aim-llama-3-1-8b-instruct.yaml
```
HTTPRoute key fragment:
```yaml
# http-route-aim-llama-3-1-8b-instruct.yaml
spec:
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /aim-llama-3-1-8b-instruct
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
```
The external path prefix `/aim-llama-3-1-8b-instruct` is rewritten to `/` for the backend service.

Example test request:
```bash
curl -s -X POST http://<GATEWAY_HOST>/aim-llama-3-1-8b-instruct/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Hello"}'
```
Adjust path segment after the prefix per runtime API (e.g. /v1/completions).

## Key Configuration Points

### PVC
```yaml
# model-store-pvc.yaml
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: rwx-nfs
  resources:
    requests:
      storage: 200Gi
```
- RWX access enables sharing between downloader job and predictor pods.

### Download Job
```yaml
# download-aim-llama-3.1-8b.yaml
command: ["bash","-c","pip install huggingface_hub[cli] && hf download --local-dir /pv/amd/Llama-3.1-8B-Instruct-FP8-KV amd/Llama-3.1-8B-Instruct-FP8-KV"]
```
- Writes model into PVC at: `/pv/amd/Llama-3.1-8B-Instruct-FP8-KV`.

### Serving Runtime
```yaml
# servingruntime-aim-llama-3.1-8b.yaml
image: amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.8.4
```
- Provides AIM engine with model and profile selection.

### Inference Service
Important fragments:
```yaml
# aim-llama-3.1-8b-instruct.yaml
model:
  runtime: aim-llama-3-1-8b-instruct-runtime
  storageUri: 'pvc://model-store-pvc/'
  env:
  - name: AIM_CACHE_PATH
    value: /mnt/models/
  - name: AIM_ENGINE_ARGS
    value: '{"otlp-traces-endpoint": "http://lgtm-stack.otel-lgtm-stack.svc:4317", "collect-detailed-traces": "all", "async-scheduling": false, "max-num-batched-tokens": 32768}'
  - name: OTEL_SERVICE_NAME
    value: "aim-llama-3-1-8b-instruct"
resources:
  limits:
    memory: "32Gi"
    cpu: "2"
    amd.com/gpu: "1"
```
- PVC contents appear at `/mnt/models/`.
- Autoscaling metrics can reference the predictor deployment service label; if using Prometheus query adjust service name to `aim-llama-3-1-8b-instruct-predictor`.

## Autoscaling (Prometheus External Metric)
If using KEDA with Prometheus:
```yaml
autoScaling:
  metrics:
  - type: External
    external:
      metric:
        backend: prometheus
        serverAddress: http://lgtm-stack.otel-lgtm-stack.svc:9090
        query: 'sum(vllm:num_requests_running{service="isvc.aim-llama-3-1-8b-instruct-predictor"})'
      target:
        type: Value
        value: "1"
```
Adjust threshold (`value`) per concurrency needs.

## Tracing
- Sidecar injection annotation: `sidecar.opentelemetry.io/inject: "otel-lgtm-stack/vllm-sidecar-collector"`
- `AIM_ENGINE_ARGS` and `OTEL_SERVICE_NAME` configure OpenTelemetry export.

## Cleanup
Clean up deployed resources.
```bash
kubectl delete -f http-route-aim-llama-3-1-8b-instruct.yaml
kubectl delete -f aim-llama-3.1-8b-instruct.yaml
kubectl delete -f servingruntime-aim-llama-3.1-8b.yaml
kubectl delete -f download-aim-llama-3.1-8b.yaml
kubectl delete -f model-store-pvc.yaml
```

Quick (delete everything created via folder apply):
```bash
kubectl delete -f ./kserve/sample-full-aims-deployment/
```

## See Also
- [Model Caching](../docs/models/model-caching.md) for more information on PVC model caching.
- KServe Storage Provider Docs: https://kserve.github.io/website/docs/model-serving/storage/providers/pvc
