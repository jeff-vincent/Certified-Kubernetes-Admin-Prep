# Kubernetes CKA Practice Exam --- 60 Minutes

------------------------------------------------------------------------

## Task 1 --- Restore Node Readiness (Node Troubleshooting)

### Problem

One of the cluster nodes is in a `NotReady` state.

### Your Job

-   Identify the root cause of the node failure.
-   Restore the node to a healthy `Ready` state.

### Constraints

-   Do **not** remove the node from the cluster.
-   Do **not** re-run `kubeadm init` or reset the cluster.

### Success Criteria

``` bash
kubectl get nodes
# All nodes must report Ready
```

------------------------------------------------------------------------

## Task 2 --- Fix Pod Networking (CNI)

### Problem

Application pods are failing to communicate and some `kube-system` pods
may not be starting correctly.

### Your Job

-   Diagnose and repair the broken CNI configuration on the affected
    node.
-   Restore functional pod networking.

### Success Criteria

-   All pods in the `kube-system` namespace are `Running` or
    `Completed`.
-   You can successfully create and schedule new pods.
-   Pod-to-pod networking works as expected.

------------------------------------------------------------------------

## Task 3 --- Stabilize the Control Plane (Static Pods)

### Problem

The Kubernetes API server is unstable and may be restarting repeatedly.

### Your Job

-   Diagnose the issue with the `kube-apiserver` static pod.
-   Correct the misconfiguration without resetting etcd or
    reinitializing the cluster.

### Constraints

-   Do **not** run `kubeadm init` again.
-   Do **not** reset or wipe etcd data.

### Success Criteria

``` bash
kubectl get --raw=/healthz
# Must return "ok"
```

------------------------------------------------------------------------

## Task 4 --- Repair RBAC Permissions (Authorization)

### Problem

A workload using the ServiceAccount `exam-app` in the `default`
namespace cannot list pods.

### Your Job

-   Modify RBAC configuration so the ServiceAccount has permission to
    list pods.

### Success Criteria

``` bash
kubectl auth can-i list pods   --as=system:serviceaccount:default:exam-app
```

Expected output:

    yes

------------------------------------------------------------------------

## Task 5 --- Fix a Failing Deployment (Workloads)

### Problem

The deployment named `exam-app` is failing and stuck in a non-ready
state.

### Your Job

-   Investigate why the deployment is failing.
-   Modify the deployment so that it runs successfully.

### Success Criteria

``` bash
kubectl get deploy exam-app
```

Expected state:

    1/1 ready replicas

------------------------------------------------------------------------

## Task 6 --- Fix ConfigMap Usage (Configuration)

### Problem

The pod `config-broken` is failing due to a misconfigured ConfigMap
reference.

### Your Job

-   Correct the configuration so that the pod starts successfully.

### Success Criteria

``` bash
kubectl get pod config-broken
```

Expected state:

    STATUS = Running

------------------------------------------------------------------------

## Task 7 --- Fix Service and DNS (Networking)

### Problem

The Service `exam-service` is not routing traffic to any pods.

### Your Job

-   Correct the Service so that it properly selects and routes traffic
    to a running pod.

### Success Criteria

``` bash
kubectl run tmp --image=busybox --restart=Never -it --rm --   wget -qO- http://exam-service.default
```

The command should successfully connect to the Service.

------------------------------------------------------------------------

## Task 8 --- Resolve Persistent Storage Issues (Storage)

### Problem

PersistentVolumeClaim `exam-pvc` is stuck in `Pending`.

### Your Job

-   Correct the storage configuration so the PVC successfully binds.
-   Do **not** delete the existing PVC.

### Success Criteria

``` bash
kubectl get pvc exam-pvc
```

Expected state:

    STATUS = Bound

------------------------------------------------------------------------

## Final Completion Criteria

You have successfully completed the exam when:

-   All nodes are in `Ready` state.
-   All `kube-system` pods are healthy.
-   The API server is stable and responsive.
-   RBAC permissions are correctly configured.
-   The `exam-app` deployment is healthy.
-   The `config-broken` pod is running.
-   The `exam-service` routes traffic correctly.
-   The `exam-pvc` is successfully bound.
