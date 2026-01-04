# Kubernetes CKA Practice Tasks

* Purpose: Hands-on troubleshooting tasks simulating real-world Kubernetes administrator scenarios
* Goal: Restore the cluster to a fully healthy state by completing all tasks

---

## Task 1: Restore Node Readiness

### Problem Description

* One of the cluster nodes is in a `NotReady` state

### Task

* Identify the cause of the node failure
* Restore the node so that all nodes report `Ready`

### Constraints

* Do not remove the node from the cluster
* Do not reinitialize the cluster

### Expected Cluster State After Solution

```bash
kubectl get nodes
```

* All nodes report `Ready`

---

## Task 2: Fix Pod Networking

### Problem Description

* Application pods are failing to communicate
* Some system pods may not start correctly

### Task

* Restore pod networking so that workloads can communicate normally

### Expected Cluster State After Solution

* All pods in the `kube-system` namespace are in `Running` or `Completed` state
* Newly created pods can be scheduled successfully
* Pod-to-pod networking functions correctly

---

## Task 3: Stabilize the Control Plane

### Problem Description

* The Kubernetes API server is unstable
* The API server may restart repeatedly

### Task

* Diagnose the cause of the instability
* Fix the control plane so the API server remains healthy and responsive

### Constraints

* Do not run `kubeadm init` again
* Do not reset etcd data

### Expected Cluster State After Solution

```bash
kubectl get componentstatuses
kubectl get --raw=/healthz
```

* Control plane components report healthy status
* API server health endpoint responds successfully

---

## Task 4: Repair RBAC Permissions

### Problem Description

* A workload running under a ServiceAccount cannot access Kubernetes resources

### Task

* Modify RBAC so that the ServiceAccount `crashy-app` in the `default` namespace can list pods

### Expected Cluster State After Solution

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:crashy-app
```

* Command output is `yes`

---

## Task 5: Fix a Failing Deployment

### Problem Description

* A deployment named `crashy-app` is failing to reach a healthy state

### Task

* Investigate the deployment failure
* Modify the deployment so it runs successfully

### Expected Cluster State After Solution

```bash
kubectl get deploy crashy-app
```

* Deployment reports `1/1` ready replicas

---

## Task 6: Resolve Persistent Storage Issues

### Problem Description

* A PersistentVolumeClaim is stuck in the `Pending` state

### Task

* Correct the storage configuration so the claim binds successfully

### Constraints

* Do not delete the PVC
* You may modify cluster storage resources

### Expected Cluster State After Solution

```bash
kubectl get pvc broken-pvc
```

* PVC status is `Bound`

---

## Completion Criteria

* All nodes are in `Ready` state
* Control plane components are stable
* System and application workloads are healthy
* Persistent storage resources are bound correctly
* Validation script completes without errors
