# Challenge 5 – Deployment Automation

While working on **Challenge 5**, I noticed that the assignment description referenced **two different types of tasks in different parts of the challenge list**:

1. **Ansible-based deployment**
2. **Helm-based Kubernetes deployment**

Because it was not completely clear which one was the intended implementation for Challenge 5, I decided to **implement both solutions** to ensure that all possible requirements are covered.

This directory therefore contains:

- an **Ansible solution** for container build and deployment
- a **Helm solution** for Kubernetes deployment

Both implementations are fully runnable and validated with helper scripts.

---

# 1. Ansible Implementation

The Ansible solution automates the deployment workflow described in the challenge instructions.

The playbook performs the following steps:

1. Add a server in the inventory  
2. Install a container runtime  
3. Prefer **Docker** if it is available  
4. If Docker is not installed, automatically **install and use Podman**  
5. Build the Docker image from the **Challenge-3 Dockerfile**  
6. Deploy the container  
7. Verify the HTTP endpoint  

The HTTP check validates the expected behaviour of the service.

Expected request:
