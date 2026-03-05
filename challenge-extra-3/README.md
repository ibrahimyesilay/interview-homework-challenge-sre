
# Extra Challenge 3 – Helm Chart Testing

This directory contains automated tests for the **Challenge‑5 Helm chart** using the **helm‑unittest** framework.

The goal of this challenge is to validate that the Helm chart renders the expected Kubernetes resources and configuration without requiring a running Kubernetes cluster.

Helm unit tests work purely on **rendered templates**, which makes them fast and deterministic.

---

# Overview

The tests verify that the Helm chart correctly renders:

- A **Deployment**
- A **Service**
- Correct container port configuration
- Correct service port exposure
- Presence of selectors and labels

These tests ensure that the chart behaves as expected when rendered by Helm.

---

# Test Framework

Tests are implemented using:

**helm‑unittest**  
https://github.com/helm-unittest/helm-unittest

This plugin allows writing test suites that validate rendered Helm templates.

---

# Project Structure

```
challenge-extra-3/
│
├── run.sh
├── README.md
└── tests/
    ├── deployment_test.yaml
    └── service_test.yaml
```

### run.sh

Automation script that:

1. Verifies Helm is installed
2. Installs the `helm-unittest` plugin if missing
3. Copies the test suites into the Helm chart
4. Executes the tests

### tests/

Contains Helm unittest suites validating Deployment and Service templates.

---

# Requirements

The following tools must be available:

- Helm v3
- Bash
- helm‑unittest plugin (installed automatically by `run.sh`)

No Kubernetes cluster is required because tests run against rendered templates.

---

# Running the Tests

From the `challenge-extra-3` directory:

```bash
chmod +x run.sh
./run.sh
```

The script will:

1. Check Helm installation
2. Install `helm-unittest` if needed
3. Copy the tests to the Helm chart
4. Execute the tests

---

# Example Output

```
==> Running helm unittest

### Chart [ server-chart ] ../challenge-5/server-chart

 PASS  Deployment renders correctly    ../challenge-5/server-chart/tests/deployment_test.yaml
 PASS  Service renders correctly       ../challenge-5/server-chart/tests/service_test.yaml

Charts:      1 passed, 1 total
Test Suites: 2 passed, 2 total
Tests:       9 passed, 9 total
Snapshot:    0 passed, 0 total
Time:        8.15175ms

✔ All helm-unittest suites passed. Done.
```

---

# What is Being Tested

## Deployment Tests

The Deployment tests verify:

- The resource kind is `Deployment`
- The API version is `apps/v1`
- The container exposes **port 8080**
- The container image can be configured via values
- Deployment contains required selector and label structure

---

## Service Tests

The Service tests verify:

- The resource kind is `Service`
- The API version is `v1`
- The Service exposes **port 8080**
- The Service has a valid `targetPort`
- The Service includes a selector to route traffic to pods

Note:

Some Helm charts use a **named targetPort** (for example `http`) instead of a numeric value like `8080`.  
The tests are written to remain compatible with this pattern.

---

# Design Decisions

### Plugin verification

Some Helm versions require plugin verification.  
The install step uses:

```
--verify=false
```

to avoid installation failures caused by unsigned plugins.

---

### Stable Test Assertions

Tests avoid advanced assertions that can cause instability in certain plugin versions and instead rely on:

- `equal`
- `isKind`
- `isAPIVersion`
- `isNotNull`

This keeps the tests stable across Helm environments.

---

# Result

All tests successfully pass:

- **2 Test Suites**
- **9 Total Tests**
- **0 Failures**

This confirms that the Helm chart correctly renders the expected Kubernetes resources.

---

# Conclusion

Helm unit testing provides a fast and reliable method for validating Helm chart behavior during development and CI pipelines.

The implemented tests confirm that:

- The Deployment configuration is valid
- The Service configuration exposes the expected ports
- The Helm chart renders correctly with configurable values

This ensures confidence that the Helm chart behaves correctly before being deployed to Kubernetes.

---
