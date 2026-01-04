# Kubernetes CKA Practice Tasks — Scenario 02

> **Scenario theme:** Everything exists, but nothing works.
>
> These tasks focus on subtle misconfigurations involving kubelet drift, CNI binaries, DNS, RBAC scope, image pulls, and storage classes.

---

## Task 1: Restore Node Stability

### Problem Description

* The node reports `Ready`
* Workloads fail intermittently

### Task

* Investigate kubelet configuration drift
* Restore stable node behavior

### Success Criteria

```bash
kubectl get nodes
```

* All nodes report `Ready`
* Workloads schedule and run reliably

---

## Task 2: Fix Pod Networking (Binary vs Config)

### Problem Description

* CNI configuration exists on the node
* CNI plugin binary is missing

### Task

* Restore consistency between CNI configuration and installed plugin binaries

### Success Criteria

* Pods can successfully create sandboxes
* All pods in the `kube-system` namespace are stable

---

## Task 3: Restore Cluster DNS

### Problem Description

* Pods can start successfully
* DNS resolution inside pods fails

### Task

* Diagnose and repair cluster DNS configuration

### Hint

```bash
kubectl exec -it <pod> -- nslookup kubernetes.default
```

### Success Criteria

* DNS resolution works correctly inside pods

---

## Task 4: Repair RBAC Scope

### Problem Description

* A ServiceAccount exists
* Permissions are defined in the wrong namespace or scope

### Task

* Correct the RBAC configuration so the ServiceAccount has the intended access

### Success Criteria

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:broken-app
```

* Command output is `yes`

---

## Task 5: Fix Image Pull Failure

### Problem Description

* Deployment is stuck in `ImagePullBackOff`

### Task

* Identify and correct the image configuration

### Success Criteria

```bash
kubectl get deploy crashy-app
```

* Deployment reports ready replicas

---

## Task 6: Resolve StorageClass Mismatch

### Problem Description

* A PersistentVolumeClaim is stuck in `Pending`
* StorageClass does not match any available PersistentVolume

### Constraints

* Do **not** delete the PVC

### Task

* Correct the storage configuration so the PVC can bind successfully

### Success Criteria

```bash
kubectl get pvc broken-pvc
```

* PVC status is `Bound`

---

## Completion Criteria

* Nodes are stable and workloads run reliably
* Pod networking and DNS function correctly
* RBAC permissions are scoped correctly
* Application deployments are healthy
* Persistent storage resources are bound successfully
