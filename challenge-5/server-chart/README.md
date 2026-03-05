# Challenge 5 -- Deployment Automation

While working on **Challenge 5**, I noticed that the assignment
description referenced **two different types of tasks in different parts
of the challenge list**:

1.  **Ansible-based deployment**
2.  **Helm-based Kubernetes deployment**

Because it was not completely clear which one was the intended
implementation for Challenge 5, I decided to **implement both
solutions** to ensure that all possible requirements are covered.

This directory therefore contains:

-   an **Ansible solution** for container build and deployment
-   a **Helm solution** for Kubernetes deployment

Both implementations are runnable and validated with helper scripts.

------------------------------------------------------------------------

# 1. Ansible Implementation

The Ansible solution automates the deployment workflow described in the
challenge instructions.

The playbook performs the following steps:

1.  Add a server in the inventory
2.  Install a container runtime
3.  Prefer **Docker** if it is available
4.  If Docker is not installed, automatically **install and use Podman**
5.  Build the Docker image from the **Challenge‑3 Dockerfile**
6.  Deploy the container
7.  Verify the HTTP endpoint

The HTTP verification validates the expected behaviour of the server.

Expected request:

Header: `Challenge: orcrist.org`

Expected response:

    HTTP 200
    Everything works!

------------------------------------------------------------------------

## Running the Ansible deployment

Run the helper script:

``` bash
./run-ansible.sh
```

The script will:

-   run the Ansible playbook locally
-   print the deployment steps
-   save the execution output to:

```{=html}
<!-- -->
```
    ansible.log

This satisfies the requirement:

> Save the output of the ansible-playbook execution in ansible.log file
> and upload.

------------------------------------------------------------------------

# 2. Helm Implementation

Another part of the challenge description refers to **Challenge 5 as a
Helm deployment task**.

To cover this interpretation as well, a **Helm chart** was also
implemented.

The chart deploys the Python HTTP server from **Challenge 3** to
Kubernetes.

Helm chart location:

    server-chart/

Chart contents:

    Chart.yaml
    values.yaml
    templates/deployment.yaml
    templates/service.yaml
    templates/_helpers.tpl

------------------------------------------------------------------------

## Running Helm validation

A helper script is included to validate the Helm chart.

``` bash
./run-helm.sh
```

The script verifies:

-   `helm lint`
-   `helm template`
-   Deployment exposes **containerPort 8080**
-   Service exposes **port 8080**

If a Kubernetes cluster is available, it can also install the chart and
test the service.

------------------------------------------------------------------------

# Project Structure

    challenge-5
    │
    ├── main.yml
    ├── inventory.ini
    ├── run-ansible.sh
    ├── run-helm.sh
    ├── ansible.log
    │
    └── server-chart
        ├── Chart.yaml
        ├── values.yaml
        └── templates
            ├── deployment.yaml
            ├── service.yaml
            └── _helpers.tpl

------------------------------------------------------------------------

# Summary

Since the challenge description referenced **both Ansible and Helm
solutions in different parts of the assignment**, both approaches were
implemented.

  Approach   Purpose
  ---------- -------------------------------------------
  Ansible    Container build and deployment automation
  Helm       Kubernetes deployment

Both solutions are included to ensure that **Challenge 5 requirements
are satisfied regardless of which interpretation was intended**.
