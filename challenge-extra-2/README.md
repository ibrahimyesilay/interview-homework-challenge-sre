
# Kubernetes Infrastructure Provisioning with Pulumi

This repository contains the implementation of **Extra Challenge 2** of the SRE interview assignment.

The goal of this challenge is to provision Kubernetes resources **using Infrastructure as Code**, without relying on static YAML manifests.

Instead of using Terraform, this solution uses **Pulumi with Python**, allowing infrastructure to be defined using real programming constructs and modular code.

The deployment runs on a **local Kubernetes cluster (Minikube)** and provisions all resources programmatically.

---

# Repository Structure

challenge-extra-2
│
├── __main__.py
├── run.sh
├── destroy.sh
│
├── Pulumi.yaml
├── Pulumi.dev.yaml
│
├── requirements.txt
├── README.md
│
└── infra
    ├── __init__.py
    ├── config.py
    ├── exports.py
    ├── namespaces.py
    ├── nginx.py
    └── pods.py

---

# File Overview

## __main__.py

Main Pulumi program entrypoint.

This file orchestrates the infrastructure deployment:

- creates namespaces
- deploys nginx
- creates example pods
- exports useful outputs

Execution flow:

create_namespaces()
deploy_nginx()
create_example_pods()
export_basic()

---

## infra/config.py

Central configuration file for infrastructure parameters.

Contains values such as:

- namespaces
- nginx image
- nginx service name
- replica count

Using a config module avoids hardcoding values across infrastructure modules.

---

## infra/namespaces.py

Responsible for creating Kubernetes namespaces.

Namespaces created:

- collector
- integration
- orcrist
- monitoring
- tools

Pulumi resource type:

kubernetes:core/v1:Namespace

---

## infra/nginx.py

Deploys the nginx application in the **orcrist** namespace.

Resources created:

- Deployment (3 replicas)
- ClusterIP Service

Deployment configuration:

image: nginx:latest
replicas: 3

---

## infra/pods.py

Creates example pods across namespaces to validate namespace separation.

Pods created:

pod-example-integration → integration namespace → busybox
pod-example-monitoring → monitoring namespace → busybox
pod-example-orcrist → orcrist namespace → busybox
pod-nginx-tools → tools namespace → nginx

---

## infra/exports.py

Exports Pulumi stack outputs such as:

- namespace list
- nginx image
- service name

These can be viewed with:

pulumi stack output

---

# Pulumi Configuration

## Pulumi.yaml

Defines the Pulumi project.

Example:

name: challenge-extra-2
runtime: python
description: Kubernetes provisioning using Pulumi

---

## Pulumi.dev.yaml

Defines stack-specific configuration and encryption metadata.

---

# Requirements

The following tools must be installed:

- Python 3
- kubectl
- minikube
- pulumi
- curl

Verify installation:

python3 --version
kubectl version --client
minikube version
pulumi version

---

# Installation

Clone the repository:

git clone <repository>
cd challenge-extra-2

---

# Running the Infrastructure

Provision everything using:

chmod +x run.sh
./run.sh

The script performs the following steps:

1. Ensures Minikube cluster is running
2. Creates a Python virtual environment
3. Installs Pulumi dependencies
4. Uses Pulumi **local backend** (no Pulumi Cloud login required)
5. Deploys Kubernetes infrastructure
6. Validates resources
7. Performs an nginx connectivity test

---

# Accessing nginx

The script automatically performs a port-forward test.

Manual access:

kubectl port-forward -n orcrist svc/nginx-service 8080:80

Then open:

http://localhost:8080

---

# Validation Commands

Verify deployment manually:

kubectl get ns
kubectl get pods -A
kubectl get svc -A

---

# Destroying the Infrastructure

To remove all resources:

chmod +x destroy.sh
./destroy.sh

The destroy script performs:

1. pulumi destroy
2. Pulumi stack removal
3. Minikube cluster deletion

---

# Pulumi Local Backend

This project intentionally uses a **local Pulumi backend**.

pulumi login --local

Benefits:

- no Pulumi Cloud account required
- no API token required
- works offline
- ideal for interview assignments

---

# Dependency Management

Dependencies are installed automatically in a Python virtual environment:

.venv/

Python packages are defined in:

requirements.txt

Main dependency:

pulumi
pulumi-kubernetes

---

# Git Ignore

Recommended .gitignore entries:

__pycache__/
*.pyc
.venv/
.pulumi/
.DS_Store

---

# Summary

This project demonstrates:

- Infrastructure as Code using Pulumi
- Kubernetes provisioning without static manifests
- Modular infrastructure design
- Automated deployment and cleanup
- Local reproducible Kubernetes environment

The repository structure and automation scripts provide a **clean, maintainable, and reproducible infrastructure provisioning workflow suitable for SRE environments.**
