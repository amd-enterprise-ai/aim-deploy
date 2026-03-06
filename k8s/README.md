# Kubernetes deployments

This directory contains different Kubernetes examples for deploying AIM (AMD Inference Microservices).

## Directory Structure

### [sample-minimal-aims-deployment](./sample-minimal-aims-deployment)

A minimal deployment example using plain Kubernetes YAML manifests. This approach provides direct control over deployment
and service configurations without additional tooling dependencies. Ideal for simple deployments and learning how AIM
works with Kubernetes resources.

### [sample-minimal-aims-helm-deployment](./sample-minimal-aims-helm-deployment)

A Helm chart-based deployment that provides templating and easier configuration management for AIM deployments. Includes
multiple model configuration overrides and supports parameterized deployments. Recommended when deploying multiple model
variants.

## Prerequisites

- Kubernetes cluster
- AMD GPU with ROCm support (e.g., MI300X)
