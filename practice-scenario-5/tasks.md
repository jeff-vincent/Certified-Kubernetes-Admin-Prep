# Scenario 05 — Stateful Workloads & Networking Edge Cases

> **Theme:** Applications start… but behave strangely.

## Task 1: Debug StatefulSet Startup Failures

### Problem Description

* StatefulSet pods fail to become ready

### Task

* Inspect volume claims and ordering guarantees

### Success Criteria

* StatefulSet pods start in order and become ready

---

## Task 2: Fix Headless Service Resolution

### Problem Description

* Pods cannot resolve peers via DNS

### Task

* Inspect Service and DNS configuration

### Success Criteria

```bash
kubectl exec -it <pod> -- nslookup <service-name>
```

* DNS resolves correctly

---

## Task 3: Restore NetworkPolicy Connectivity

### Problem Description

* Traffic between pods is unexpectedly blocked

### Task

* Diagnose NetworkPolicy rules

### Success Criteria

* Intended pod-to-pod traffic flows

---

## Task 4: Fix Persistent Volume Mount Failures

### Problem Description

* Pods fail to mount bound volumes

### Task

* Inspect volume mount paths and permissions

### Success Criteria

* Pods mount volumes successfully

---

## Task 5: End-to-End Application Validation

### Success Criteria

* Stateful workload is stable
* Networking and storage behave as expected

---

## Overall Completion Criteria

Across all five scenarios:

* Nodes remain healthy and stable
* Control plane components are reliable
* Networking, DNS, RBAC, scheduling, and storage issues are resolved
* Validation scripts complete successfully

> **Outcome:** You are operating at real-world Kubernetes administrator level, not just exam readiness.
