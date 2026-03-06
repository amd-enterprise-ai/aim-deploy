# Running AIM with Docker

This guide provides step-by-step instructions for running AMD Inference Microservice (AIM) container for
 meta-llama/Llama-3.1-8B-Instruct model with Docker. Follow these instructions to quickly get started with running an AI model on AMD GPUs.

## Prerequisites

* AMD GPU with ROCm support (e.g., MI300X, MI325X)
* Docker installed and configured with GPU support
* Access to model repositories (Hugging Face account with appropriate permissions for gated models)

## 1. Docker deployment

### 1.1 Running the container

```bash
docker run \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  --device=/dev/kfd --device=/dev/dri \
  -p 8000:8000 \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0
```

Where <YOUR_HUGGINGFACE_TOKEN> is your Hugging Face access token (required for gated models)

### 1.2 Customizing deployment with environment variables

Customize your deployment with optional environment variables:

```bash
docker run \
  -e AIM_PRECISION=fp16 \
  -e AIM_GPU_COUNT=1 \
  -e AIM_METRIC=throughput \
  -e AIM_PORT=8080 \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  --device=/dev/kfd --device=/dev/dri \
  -p 8080:8080 \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0
```

## 2. Model caching for production

For production environments, pre-download models to a persistent cache:

### 2.1 Download model to cache

Model can be downloaded either by using the model-specific image or the base image. By default, the profile selection
and GPU detection are executed before downloading to ensure fetching of a correct model. The command `download-to-cache`
provides an option `--model-id` that allows to bypass these procedures. It should be used when the specific model is
known in advance or GPU usage has to be minimized.

```bash
# Create persistent cache directory
mkdir -p /path/to/model-cache

# Downloading models with running GPU detection and profile selection:

# Download model using the download-to-cache command with model-specific image.
docker run --rm \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  -v /path/to/model-cache:/workspace/model-cache \
  --device=/dev/kfd --device=/dev/dri \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.8.5 \
  download-to-cache

# Downloading a model using base image and skipping GPU detection and profile selection:
docker run --rm \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  -v /path/to/model-cache:/workspace/model-cache \
  amdenterpriseai/aim-base:0.10 \
  download-to-cache --model-id meta-llama/Llama-3.1-8B-Instruct
```

### 2.2 Run with pre-cached model

```bash
docker run \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  -v /path/to/model-cache:/workspace/model-cache \
  --device=/dev/kfd --device=/dev/dri \
  -p 8000:8000 \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0
```

## 3. Testing your deployment

To test the deployment, execute an API call using `completion` method.

### 3.1 Using curl

```bash
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "prompt": "Once upon a time,",
    "max_tokens": 50,
    "temperature": 0.7
  }'
```

### 3.2 Using Python

```python
import requests

response = requests.post(
    "http://localhost:8000/v1/completions",
    json={
        "model": "meta-llama/Llama-3.1-8B-Instruct",
        "prompt": "Once upon a time,",
        "max_tokens": 50,
        "temperature": 0.7
    }
)

print(response.json())
```

## 4. Advanced deployment scenarios

### 4.1 Using custom profiles

```bash
# Create custom profile directory
mkdir -p custom-profiles

# Add your custom profile YAML
cat > custom-profiles/vllm-custom-profile.yaml << EOF
aim_id: meta-llama/Llama-3.1-8B-Instruct
model_id: meta-llama/Llama-3.1-8B-Instruct
metadata:
  engine: vllm
  gpu: MI300X
  precision: fp16
  gpu_count: 1
  metric: throughput
  manual_selection_only: false
  type: unoptimized

engine_args:
  gpu-memory-utilization: 0.95
  dtype: float16
  tensor-parallel-size: 1
  max-num-batched-tokens: 1024
  max-model-len: 2048

env_vars:
  VLLM_DO_NOT_TRACK: "1"
  VLLM_ALLOW_LONG_MAX_MODEL_LEN: "1"
EOF

# Run with custom profile
docker run \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  -v $(pwd)/custom-profiles:/workspace/aim-runtime/profiles/custom \
  -e AIM_METRIC=throughput \
  --device=/dev/kfd --device=/dev/dri \
  -p 8000:8000 \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0
```

## 5. Monitoring and troubleshooting

### 5.1 Getting help on the commands

A general help command is available as follows:

```bash
docker run \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0 \
  --help
```

A help command for specific subcommands is also available:

```bash
docker run \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0 \
  <subcommand> --help
```

### 5.2 Enabling detailed logging

```bash
docker run \
  -e AIM_LOG_LEVEL=DEBUG \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  --device=/dev/kfd --device=/dev/dri \
  -p 8000:8000 \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0
```

### 5.3 Checking profile selection results

It is possible to check which profile AIM selects based on the provided environment variables.

```bash
docker run \
  -e AIM_GPU_COUNT=1 \
  -e AIM_PRECISION=fp16 \
  -e AIM_GPU_MODEL=MI300X \
  -e HF_TOKEN=<YOUR_HUGGINGFACE_TOKEN> \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0 \
  dry-run
```

### 5.4 List available profiles

```bash
docker run \
  amdenterpriseai/aim-meta-llama-llama-3-1-8b-instruct:0.10.0 \
  list-profiles
```

## 6. Security considerations

* Never include HF_TOKEN in Dockerfiles or commit it to version control
