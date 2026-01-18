# Kubernetes CKA Practice Exam --- Scenario 2 (Troubleshooting)

> **Time limit:** 60 minutes\
> This exam assumes a two-node cluster (1 control-plane, 1 worker).

------------------------------------------------------------------------

## Task 1 --- Recover a Crashed Container Runtime (Node Troubleshooting)

### Problem

One of your worker nodes shows pods stuck in `ContainerCreating` and the
node may appear `NotReady`.

### Your Job

-   Identify why containers are failing to start on the worker.
-   Restore normal container runtime operation on the affected node.

### Constraints

-   Do **not** remove the node from the cluster.
-   Do **not** reset the cluster or rerun `kubeadm`.

### Success Criteria

``` bash
kubectl get nodes
# All nodes report Ready
```

------------------------------------------------------------------------

## Task 2 --- Repair kube-proxy Networking

### Problem

Services are intermittently unreachable from pods on the worker node.

### Your Job

-   Diagnose and fix the kube-proxy problem on the affected node.
-   Ensure ClusterIP Services work reliably again.

### Success Criteria

-   `kube-proxy` pod on the worker is `Running`
-   You can curl a ClusterIP Service from a pod on the worker node.

------------------------------------------------------------------------

## Task 3 --- Fix Broken Static Pod (Scheduler)

### Problem

The kube-scheduler static pod is crashing on the control plane.

### Your Job

-   Locate and correct the misconfiguration in the scheduler manifest.
-   Restore a stable, running scheduler.

### Success Criteria

``` bash
kubectl get pod -n kube-system kube-scheduler-$(hostname) | grep Running
```

------------------------------------------------------------------------

## Task 4 --- Correct ClusterRoleBindings (Authorization)

### Problem

A ServiceAccount `ops-audit` in namespace `monitoring` cannot get or
list nodes.

### Your Job

-   Modify RBAC so this ServiceAccount can `get` and `list` nodes
    cluster-wide.

### Success Criteria

``` bash
kubectl auth can-i list nodes --as=system:serviceaccount:monitoring:ops-audit
# yes
```

------------------------------------------------------------------------

## Task 5 --- Repair a Broken StatefulSet (Workloads)

### Problem

A StatefulSet named `db` in namespace `default` is not creating its
pods.

### Your Job

-   Investigate the cause (volume/template/selector issues are likely).
-   Fix the StatefulSet so it successfully runs 1 replica.

### Success Criteria

``` bash
kubectl get sts db
# 1/1 ready replicas
```

------------------------------------------------------------------------

## Task 6 --- Fix Secret Injection (Configuration)

### Problem

Pod `secret-consumer` is crashing because of an invalid Secret
reference.

### Your Job

-   Correct the pod spec so it starts successfully using the intended
    Secret.

### Success Criteria

``` bash
kubectl get pod secret-consumer
# STATUS = Running
```

------------------------------------------------------------------------

## Task 7 --- Repair Ingress Routing (Networking)

### Problem

An Ingress `web-ingress` exists but returns 404 for all paths.

### Your Job

-   Fix the Ingress and/or backend Service so requests reach a running
    pod.

### Success Criteria

``` bash
curl -I http://web.example.local/
# HTTP/1.1 200 OK
```

------------------------------------------------------------------------

## Task 8 --- Resolve Storage Binding (Storage)

### Problem

PVC `app-data` is stuck in `Pending` due to a StorageClass or PV
mismatch.

### Your Job

-   Correct the storage configuration so the PVC binds **without
    deleting it**.

### Success Criteria

``` bash
kubectl get pvc app-data
# STATUS = Bound
```

------------------------------------------------------------------------

## Final Completion Criteria

You have successfully completed the exam when: - All nodes are Ready. -
All kube-system pods are healthy. - The scheduler is stable. - RBAC is
correctly configured for `ops-audit`. - StatefulSet `db` is healthy. -
Pod `secret-consumer` is Running. - Ingress routes traffic correctly. -
PVC `app-data` is Bound.
