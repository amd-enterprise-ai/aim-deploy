# Model Caching with PVC

## Overview

PVC-based model caching provides persistent, shared storage for models in KServe deployments. This approach significantly improves deployment performance by eliminating repeated model downloads and enabling faster pod startup times.

## AIM Model Cache Structure

AIM supports two model cache formats within `AIM_CACHE_PATH`:

1. **Local Directory Format (recommended for PVC)**: Models stored as `AIM_CACHE_PATH/org/model/` (e.g., `/mnt/models/meta-llama/Llama-3.1-8B-Instruct`)
2. **Hugging Face Hub Cache**: Models cached in `AIM_CACHE_PATH/hub/` using Hugging Face's standard cache format

**Cache Resolution Order:**
1. **Local directory first**: If a model exists at `AIM_CACHE_PATH/org/model/`, it's loaded directly
2. **Hugging Face fallback**: Otherwise, the `model_id` is used and Hugging Face handles cache lookup or download

> **_NOTE:_** "KServe Integration"
    In KServe deployments, cached models are automatically mounted to `/mnt/models/` by KServe. AIM's `AIM_CACHE_PATH` environment variable should be set to `/mnt/models/` to utilize this mounted cache directory.


## Implementation Overview

The PVC caching approach involves three main steps:

### 1. Create Persistent Volume Claim
Set up a PVC with appropriate storage class and size for your models. ReadWriteMany (RWX) access mode is recommended for sharing across multiple pods.

### 2. Download Models to PVC
Use a Kubernetes Job to download models from external sources (like Hugging Face) directly into the PVC. **Important**: Save models using the `org/model` path pattern (e.g., `/pv/Qwen/Qwen2.5-0.5B-Instruct`) for AIM to find them automatically.

### 3. Configure InferenceService
Update your InferenceService to use:
- `storageUri: "pvc://your-pvc-name/"` to reference the PVC
- `AIM_CACHE_PATH: /mnt/models/` environment variable where KServe mounts the PVC

## Prerequisites

Before using PVC-based model caching, ensure you have:

- **Storage Class available**: The examples use `rwx-nfs`, but adapt to your cluster's storage
- **KServe configured**: `storageInitializer.enableDirectPvcVolumeMount` should be `true` (default)

## Example Use Cases

### Production Deployment
Our [Sample Full AIM Deployment](../../sample-full-aims-deployment/) demonstrates PVC caching with:
- `amd/Llama-3.1-8B-Instruct-FP8-KV` model pre-cached in a 200Gi PVC
- Automated model downloading via Kubernetes Job
- Production-ready configuration with monitoring and autoscaling

### Storage Considerations
- **Storage Class**: Use ReadWriteMany (RWX) for multi-pod access
- **Size Planning**: Account for model size plus overhead (typically 1.5-2x model size)
- **Performance**: Consider SSD-backed storage for faster model loading
- **Path Structure**: Models must follow `org/model` naming convention for AIM discovery

## Troubleshooting

Common checks for PVC-based model cache:

```bash
# Check PVC status
kubectl get pvc model-store-pvc
kubectl describe pvc model-store-pvc

# Monitor download job
kubectl get jobs
kubectl logs job/model-downloader-<job-name>

# Check InferenceService
kubectl describe inferenceservice <service-name>
kubectl logs deployment/<service-name>-predictor
```

To verify model files exist, start a pod with the volume mounted and inspect the mount manually.

## Related Documentation

- **KServe Official Documentation**: [PVC Storage Provider](https://kserve.github.io/website/docs/model-serving/storage/providers/pvc)
- **Sample Implementation**: [Full AIM Deployment Example](../../sample-full-aims-deployment/)
- **Custom Models**: [Creating Custom Model Configurations](./custom-models.md)
- **Installation Guide**: [KServe Installation](../../kserve-install/) - Set up your environment first

For detailed YAML configurations and step-by-step implementation, refer to the [KServe PVC documentation](https://kserve.github.io/website/docs/model-serving/storage/providers/pvc) and explore the full deployment example.