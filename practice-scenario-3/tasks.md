# Kubernetes CKA Practice Tasks — Scenarios 03–05

This document defines **three additional practice scenarios**, bringing the total to **five** hands-on troubleshooting labs. Each scenario mirrors real CKA-style failure modes while avoiding repetition of fixes.

---

# Scenario 03 — Control Plane & Certificates

> **Theme:** The control plane is up… but not trustworthy.

## Task 1: Investigate API Server Authentication Failures

### Problem Description

* `kubectl` intermittently fails with authentication or TLS-related errors
* Control plane pods appear to restart

### Task

* Inspect control plane component logs
* Identify certificate or flag-related misconfiguration

### Success Criteria

```bash
kubectl get componentstatuses
kubectl get --raw=/healthz
```

* API server responds successfully
* Control plane components are healthy

---

## Task 2: Restore kube-controller-manager Stability

### Problem Description

* Controller manager restarts repeatedly
* Nodes or pods do not reconcile as expected

### Task

* Diagnose static pod configuration issues
* Restore controller-manager stability

### Success Criteria

* kube-controller-manager pod remains running
* Cluster reconciliation resumes normally

---

## Task 3: Verify Node Authorization

### Problem Description

* Nodes fail to register or update status correctly

### Task

* Inspect node authorizer / RBAC configuration

### Success Criteria

```bash
kubectl get nodes
```

* Nodes report correct and stable status

---

## Task 4: Fix a Control-Plane-Critical Deployment

### Problem Description

* A system deployment depends on API access and fails

### Task

* Restore permissions or configuration required for success

### Success Criteria

* Deployment reaches ready state

---

## Task 5: Confirm Cluster Stability

### Success Criteria

* No control plane pods are restarting
* Cluster remains responsive for several minutes
