# Scenario 04 — Scheduling, Resources, and Evictions

> **Theme:** The cluster is healthy — but nothing schedules.

## Task 1: Diagnose Pending Pods

### Problem Description

* Pods remain in `Pending`
* Nodes appear healthy

### Task

* Identify scheduling constraints

### Success Criteria

* Pods transition to `Running`

---

## Task 2: Resolve Resource Requests Issues

### Problem Description

* Pods request excessive CPU or memory

### Task

* Adjust resource requests or limits appropriately

### Success Criteria

* Pods are scheduled successfully

---

## Task 3: Fix Node Taints and Tolerations

### Problem Description

* Nodes have taints preventing scheduling

### Task

* Modify taints or add tolerations

### Success Criteria

```bash
kubectl describe node
```

* Workloads schedule as expected

---

## Task 4: Address Pod Evictions

### Problem Description

* Pods are evicted shortly after starting

### Task

* Investigate eviction reasons (disk, memory, pressure)

### Success Criteria

* Pods remain running

---

## Task 5: Validate Cluster Scheduling

### Success Criteria

* New workloads schedule immediately
* No unexpected evictions occur
