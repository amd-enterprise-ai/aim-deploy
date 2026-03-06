# Using Different Models

The [sample-minimal-aims-deployment](../../sample-minimal-aims-deployment/README.md) example uses a pre-built AIM image with the Qwen3-32B model. To use different models, you'll need to create your own serving runtime and inference service configurations.

## Creating a Custom Serving Runtime

First, create a `ClusterServingRuntime` that references your custom AIM image:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ClusterServingRuntime
metadata:
  name: my-custom-model-runtime
spec:
  supportedModelFormats:
    - name: my-custom-model
  containers:
    - name: kserve-container
      image: ghcr.io/your-org/aim-model-vendor-model-name:aim_version
      imagePullPolicy: Always
      ports:
        - name: http
          containerPort: 8000
          protocol: TCP
      env:
        - name: VLLM_ENABLE_METRICS
          value: "true"
      volumeMounts:
       - mountPath: /dev/shm
         name: dshm
  volumes:
    - name: dshm
      emptyDir:
        medium: Memory
        sizeLimit: 8Gi
```

## Creating a Custom Inference Service

Then, create an `InferenceService` that uses your custom runtime:

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: my-custom-model
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    serving.kserve.io/autoscalerClass: "keda"
spec:
  predictor:
    model:
      runtime: my-custom-model-runtime  # Reference to your custom runtime
      modelFormat:
        name: my-custom-model
      resources:
        limits:
          memory: "32Gi"
          cpu: "2"
          amd.com/gpu: "1"
        requests:
          memory: "32Gi"
          cpu: "2"
          amd.com/gpu: "1"
    minReplicas: 1
    maxReplicas: 3
```

## Key Points to Remember

- **Image Reference**: Update the `image` field in the serving runtime to point to your custom AIM image
- **Runtime Name**: Choose a unique name for your `ClusterServingRuntime` and reference it in the `InferenceService`
- **Model Format**: Use a descriptive name for the `modelFormat.name` that matches your `supportedModelFormats`
- **Resource Requirements**: Adjust memory, CPU, and GPU requirements based on your model's needs
- **Naming**: Ensure all names are unique across your cluster to avoid conflicts

## Deployment

Apply your custom configurations:

```bash
kubectl apply -f your-custom-serving-runtime.yaml
kubectl apply -f your-custom-inference-service.yaml
```

## Testing Your Custom Model

Once deployed, you can test the model. First, find the service endpoint:

```bash
kubectl get inferenceservice my-custom-model
```

For local testing with port-forward:
```bash
kubectl port-forward service/my-custom-model-predictor 8000:80
```

Then test with curl:
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "your-model-name",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

Make sure to replace `my-custom-model` with the actual name of your inference service and `your-model-name` with the appropriate model identifier.

## Related Documentation

- [KServe Installation Guide](../../kserve-install/) - Set up your KServe environment first
- [Minimal Examples](../../sample-minimal-aims-deployment/) - Basic inference service examples
- [Production Example](../../sample-full-aims-deployment/) - Production-ready configuration