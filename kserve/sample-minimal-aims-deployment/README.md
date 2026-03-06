# Sample: Minimal AIM Qwen3 32B Deployment

This folder contains a basic example showing how to:

1. Define a ClusterServingRuntime for AIM
2. Deploy a simple InferenceService that serves a pre-built model

## Files

- `servingruntime-aim-qwen3-32b.yaml` – ClusterServingRuntime defining the AIM container image
- `aim-qwen3-32b.yaml` – Basic InferenceService using the runtime

## Quick Deployment

To deploy the minimal example:
```bash
kubectl apply -f ./kserve/sample-minimal-aims-deployment/
```

## Step-by-Step Deployment

### 1. Install the Serving Runtime
Defines the container image and ports used by AIM:
```bash
kubectl apply -f servingruntime-aim-qwen3-32b.yaml
```

### 2. Deploy the Inference Service
Creates a basic inference service using the pre-built Qwen3 32B model:
```bash
kubectl apply -f aim-qwen3-32b.yaml
```

Check status:
```bash
kubectl describe inferenceservice aim-qwen3-32b
kubectl logs deployment/aim-qwen3-32b-predictor
```

## Testing the Model

Once deployed, you can test the model. First, find the service endpoint:

```bash
kubectl get inferenceservice aim-qwen3-32b
```

For local testing with port-forward:
```bash
kubectl port-forward service/aim-qwen3-32b-predictor 8000:80
```

Then test with curl:
```bash
curl -X POST http://localhost:8000/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Hello","max_tokens":50}'
```

## Key Configuration Points

### Serving Runtime
```yaml
# servingruntime-aim-qwen3-32b.yaml
image: amdenterpriseai/aim-qwen-qwen3-32b:0.8.5
```
- Contains AIM engine with pre-built Qwen3 32B model

### Inference Service
```yaml
# aim-qwen3-32b.yaml
model:
  runtime: aim-qwen3-32b-runtime
  modelFormat:
    name: aim-qwen3-32b
resources:
  limits:
    memory: "8Gi"
    cpu: "1"
```
- Uses minimal resource allocation suitable for the small model
- Single replica for basic deployment

## Cleanup

Clean up deployed resources:
```bash
kubectl delete -f aim-qwen3-32b.yaml
kubectl delete -f servingruntime-aim-qwen3-32b.yaml
```

Or delete everything at once:
```bash
kubectl delete -f ./kserve/sample-minimal-aims-deployment/
```

## Next Steps

Once you have this basic example working, you can explore:
- [Full AIM Deployment](../sample-full-aims-deployment/) - Production-ready configuration with PVC caching, autoscaling, monitoring, and routing
- [Custom Models](../docs/models/custom-models.md) - Creating your own model configurations