# Sample: AIM Qwen3 32B Deployment with KV Cache (LMCache + Redis)

This folder contains an example showing how to:

1. Define a ClusterServingRuntime for AIM with LMCache enabled
2. Deploy an InferenceService that serves a AIMs model
3. Start a Redis backend to persist KV cache entries
4. Provide an LMCache configuration via ConfigMap

## Files

- `servingruntime-aim-qwen3-32b.yaml` – ClusterServingRuntime defining the AIM container image (includes lmcache at startup)
- `aim-qwen3-32b.yaml` – InferenceService using the runtime and enabling KV cache via AIM_ENGINE_ARGS
- `redis-deployment.yaml` – Redis deployment + service acting as KV cache backend
- `lmcache-config.yaml` – ConfigMap providing LMCache configuration (must exist in the same namespace as the InferenceService pods to be mounted)

## Step-by-Step Deployment

### 1. Apply LMCache ConfigMap
```bash
kubectl apply -f lmcache-config.yaml
```

### 2. Deploy Redis (KV cache backend)
```bash
kubectl apply -f redis-deployment.yaml
```
> The sample ConfigMap assumes Redis is reachable at `redis.default.svc.cluster.local:6379` (service name: redis, namespace: default). If you deploy Redis in another namespace or under a different service name, edit `remote_url` in `lmcache-config.yaml` accordingly.

### 3. Install the Serving Runtime
Defines the container image and ports used by AIM (lmcache installed at startup):
```bash
kubectl apply -f servingruntime-aim-qwen3-32b.yaml
```

### 4. Deploy the Inference Service
Creates an inference service using the pre-built Qwen3 32B model with KV cache enabled:
```bash
kubectl apply -f aim-qwen3-32b.yaml
```

Check status:
```bash
kubectl describe inferenceservice aim-qwen3-32b-kv
kubectl logs deployment/aim-qwen3-32b-kv-predictor
```

## Testing the Model

Once deployed, you can test the model. First, find the service endpoint:
```bash
kubectl get inferenceservice aim-qwen3-32b
```

For local testing with port-forward:
```bash
kubectl port-forward service/aim-qwen3-32b-kv-predictor 8000:80
```

Then test with curl:
```bash
curl -X POST http://localhost:8000/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"How much wood would a woodchuck chuck, if a woodchuck would chuck wood","max_tokens":50}'
```

## Observing LMCache Hits

Check the logs to see LMCache storing and retrieving KV tensors:
```bash
kubectl logs -l serving.kserve.io/inferenceservice=aim-qwen3-32b-kv -c kserve-container | grep "LMCache INFO"
```

Example output showing cache misses and hits:
```
LMCache INFO: Reqid: cmpl-de25fa..., Total tokens 18, LMCache hit tokens: 0, need to load: 0
LMCache INFO: Reqid: cmpl-927cf4..., Total tokens 18, LMCache hit tokens: 18, need to load: 17
```

First request has 0 hit tokens (cache miss), subsequent request with same prompt achieves 18/18 hit tokens (100% cache hit).

## Key Configuration Points

### Serving Runtime
```yaml
# servingruntime-aim-qwen3-32b.yaml
image: amdenterpriseai/aim-qwen-qwen3-32b:0.8.4
command:
- /bin/bash
- -c
- |
  git clone --branch v0.3.5 https://github.com/LMCache/LMCache.git
  cd LMCache
  pip install -r requirements/build.txt
  python3 -m pip install --no-build-isolation -e .
  cd /workspace
  exec ./entrypoint.py
```
- AIM engine image; lmcache installed dynamically via startup command

### Inference Service
```yaml
# aim-qwen3-32b.yaml
env:
- name: AIM_ENGINE_ARGS
  value: '{kv-transfer-config: {"kv_connector":"LMCacheConnectorV1", "kv_role":"kv_both"}}'
resources:
  limits:
    memory: "128Gi"
    cpu: "8"
    amd.com/gpu: "1"
```
- AIM_ENGINE_ARGS enables LMCache connector and dual role (store + retrieve)
- Single replica example with GPU + large memory for 32B model

### LMCache ConfigMap
Provides tuning and the remote Redis endpoint.
Apply before runtime and service so the volume mount resolves.
Remote URL default assumption: `redis.default.svc.cluster.local:6379` – change in `lmcache-config.yaml` under `remote_url` if needed.

### Redis Backend
Redis stores serialized KV tensors allowing reuse across requests.

## Cleanup

Clean up deployed resources:
```bash
kubectl delete -f aim-qwen3-32b.yaml
kubectl delete -f servingruntime-aim-qwen3-32b.yaml
kubectl delete -f redis-deployment.yaml
kubectl delete -f lmcache-config.yaml
```

Or delete everything at once:
```bash
kubectl delete -f ./kserve/sample-kv-cache/
```

## Next Steps

Once you have this example working, you can explore:
- [Full AIM deployment with caching, autoscaling, monitoring](../sample-full-aims-deployment/README.md)
- [Custom models](../docs/models/custom-models.md)
