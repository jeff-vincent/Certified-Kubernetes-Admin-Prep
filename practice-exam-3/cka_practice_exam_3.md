# Kubernetes CKA Practice Exam 3 — Comprehensive Gap Coverage

> **Time limit:** 120 minutes\
> **Cluster:** 2-node kubeadm cluster (1 control-plane, 1 worker) — Ubuntu 24.04, K8s v1.30, Flannel CNI\
> **Access:** SSH as root between nodes\
> **Note:** Some tasks depend on a healthy cluster. Address troubleshooting tasks early.

------------------------------------------------------------------------

## Task 1 — etcd Snapshot Backup (7%)

### Context

You are logged into the `control-plane` node. `etcdctl` is available at `/usr/local/bin/etcdctl`.

### Task

Take a snapshot of the running etcd instance and save it to **`/opt/etcd-backup.db`**.

Use the following connection details:

| Parameter  | Value                                    |
|------------|------------------------------------------|
| Endpoints  | `https://127.0.0.1:2379`                |
| CA cert    | `/etc/kubernetes/pki/etcd/ca.crt`       |
| Client cert| `/etc/kubernetes/pki/etcd/server.crt`   |
| Client key | `/etc/kubernetes/pki/etcd/server.key`   |

### Success Criteria

```bash
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db
# Should display snapshot metadata without errors
```

------------------------------------------------------------------------

## Task 2 — etcd Snapshot Restore (7%)

### Context

You are logged into the `control-plane` node. An etcd snapshot has been
pre-created at **`/opt/etcd-pre-break.db`**.

### Task

Restore the etcd snapshot to a **new data directory** at **`/var/lib/etcd-restored`**.

> You do **not** need to reconfigure the running etcd to use this
> directory. Just perform the restore operation.

### Success Criteria

```bash
ls /var/lib/etcd-restored/member/
# Should contain snap/ and wal/ subdirectories
```

------------------------------------------------------------------------

## Task 3 — Fix a Broken Worker Node (8%)

### Problem

The worker node is in a `NotReady` state. The kubelet is failing to
start.

### Your Job

-   SSH to the worker node and investigate the kubelet failure.
-   Restore the kubelet so the node returns to `Ready`.

### Constraints

-   Do **not** remove the node from the cluster.
-   Do **not** run `kubeadm reset`.

### Success Criteria

```bash
kubectl get nodes
# All nodes report Ready
```

------------------------------------------------------------------------

## Task 4 — Drain and Uncordon a Node (5%)

### Context

The worker node needs routine maintenance.

### Task

1.  **Drain** the worker node, ignoring DaemonSets:
    `kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data`
2.  SSH to the worker and create the file **`/opt/maintenance-complete`**
    (contents do not matter).
3.  **Uncordon** the worker node.

### Success Criteria

```bash
kubectl get node <worker>
# SchedulingDisabled must NOT be present
ssh root@<worker-ip> "test -f /opt/maintenance-complete && echo ok"
# ok
```

------------------------------------------------------------------------

## Task 5 — Create a DaemonSet (5%)

### Task

Create a DaemonSet with the following specification:

| Field           | Value                                                                 |
|-----------------|-----------------------------------------------------------------------|
| Name            | `log-collector`                                                      |
| Namespace       | `monitoring` *(create if it does not exist)*                         |
| Image           | `busybox`                                                            |
| Command         | `sh -c "while true; do echo collecting-logs; sleep 60; done"`        |

The DaemonSet **must run on all nodes**, including the control plane.
You will need to add the appropriate toleration.

### Success Criteria

```bash
kubectl get ds log-collector -n monitoring
# DESIRED = number of nodes (2), READY = 2
```

------------------------------------------------------------------------

## Task 6 — Multi-container Pod with Init Container (7%)

### Task

Create a pod named **`multi-pod`** in the `default` namespace with:

-   **Init container** named `init-data`
    -   Image: `busybox`
    -   Command: `sh -c "echo ready > /data/status"`
    -   Volume mount: `shared-data` at `/data`

-   **Main container** named `app`
    -   Image: `busybox`
    -   Command: `sh -c "cat /data/status && sleep 3600"`
    -   Volume mount: `shared-data` at `/data`

-   **Sidecar container** named `monitor`
    -   Image: `busybox`
    -   Command: `sh -c "while true; do echo monitoring; sleep 10; done"`
    -   Volume mount: `shared-data` at `/data`

-   **Volume**: `shared-data` of type `emptyDir`

### Success Criteria

```bash
kubectl get pod multi-pod
# STATUS = Running, READY = 2/2
kubectl get pod multi-pod -o jsonpath='{.spec.initContainers[0].name}'
# init-data
```

------------------------------------------------------------------------

## Task 7 — Rolling Update and Rollback (5%)

### Context

A deployment named **`rollout-app`** exists in the `default` namespace
running `nginx:1.24.0`.

### Task

1.  Update the deployment image to **`nginx:1.25.0`**.
2.  Wait for the rollout to complete.
3.  **Rollback** the deployment to the previous revision.

### Success Criteria

```bash
kubectl get deployment rollout-app -o jsonpath='{.spec.template.spec.containers[0].image}'
# nginx:1.24.0
kubectl rollout history deployment rollout-app
# Should show at least 2 revisions
```

------------------------------------------------------------------------

## Task 8 — Scale a Deployment and Configure Resources (5%)

### Context

A deployment named **`scale-app`** exists with 1 replica and no resource
constraints.

### Task

1.  Scale the deployment to **4 replicas**.
2.  Set container resource **requests**: `cpu: 50m`, `memory: 64Mi`
3.  Set container resource **limits**: `cpu: 200m`, `memory: 128Mi`

### Success Criteria

```bash
kubectl get deployment scale-app
# 4/4 READY
kubectl get deployment scale-app -o jsonpath='{.spec.template.spec.containers[0].resources}'
# Shows requests and limits
```

------------------------------------------------------------------------

## Task 9 — Create a NodePort Service (5%)

### Context

A deployment named **`backend-app`** exists with labels `app=backend`.

### Task

Create a Service with:

| Field      | Value         |
|------------|---------------|
| Name       | `backend-svc` |
| Type       | `NodePort`    |
| Port       | `80`          |
| TargetPort | `80`          |
| NodePort   | `30080`       |
| Selector   | `app=backend` |

### Success Criteria

```bash
kubectl get svc backend-svc
# TYPE=NodePort, PORT(S)=80:30080/TCP
curl http://<node-ip>:30080
# Returns nginx welcome page
```

------------------------------------------------------------------------

## Task 10 — Schedule a Pod with Node Affinity (5%)

### Context

The worker node has been labeled `disk=ssd`.

### Task

Create a pod named **`affinity-pod`** using the `nginx` image.
Configure **`requiredDuringSchedulingIgnoredDuringExecution`** node
affinity so the pod is only scheduled on nodes with the label
`disk=ssd`.

### Success Criteria

```bash
kubectl get pod affinity-pod -o wide
# STATUS = Running, NODE = <worker>
```

------------------------------------------------------------------------

## Task 11 — Retrieve and Save Container Logs (5%)

### Context

A pod named **`log-generator`** is running and producing log output at
various levels (INFO, WARN, ERROR).

### Task

-   Extract **only the `ERROR` level** log lines from the `log-generator` pod.
-   Save them to **`/opt/error-logs.txt`** on the control-plane node.

### Success Criteria

```bash
cat /opt/error-logs.txt
# Contains only lines with ERROR, no INFO or WARN lines
```

------------------------------------------------------------------------

## Task 12 — Create ServiceAccount and RBAC (8%)

### Context

Namespace **`dev-team`** already exists.

### Task

1.  Create a **ServiceAccount** named `deploy-bot` in namespace `dev-team`.
2.  Create a **ClusterRole** named `pod-reader` that allows `get`,
    `list`, and `watch` on `pods` across all namespaces.
3.  Create a **ClusterRoleBinding** named `pod-reader-binding` that
    binds the `deploy-bot` ServiceAccount to the `pod-reader`
    ClusterRole.

### Success Criteria

```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:dev-team:deploy-bot
# yes
kubectl auth can-i list pods \
  --as=system:serviceaccount:dev-team:deploy-bot \
  -n kube-system
# yes
```

------------------------------------------------------------------------

## Task 13 — Create a NetworkPolicy (8%)

### Context

-   Namespace **`web-app`** contains a pod `web-pod` with label `app=web`.
-   Namespace **`api-backend`** contains a pod `api-pod` with label
    `app=api`. This namespace is labeled `purpose=backend`.

### Task

Create a NetworkPolicy named **`allow-backend-only`** in namespace
`web-app` that:

-   Applies to pods with label `app=web`
-   **Allows** ingress traffic only from pods in namespaces labeled
    `purpose=backend`
-   **Denies** all other ingress traffic

### Success Criteria

```bash
kubectl get networkpolicy allow-backend-only -n web-app
# Shows the policy
kubectl describe networkpolicy allow-backend-only -n web-app
# PodSelector: app=web
# Allowing ingress from namespaceSelector: purpose=backend
```

------------------------------------------------------------------------

## Task 14 — Create PersistentVolume, PVC, and Mount in Pod (8%)

### Task

1.  Create a **PersistentVolume** named `exam-pv`:
    -   Capacity: `1Gi`
    -   Access mode: `ReadWriteOnce`
    -   HostPath: `/mnt/exam-data`
    -   StorageClassName: `manual`

2.  Create a **PersistentVolumeClaim** named `exam-pvc`:
    -   Request: `500Mi`
    -   Access mode: `ReadWriteOnce`
    -   StorageClassName: `manual`

3.  Create a **Pod** named `storage-pod`:
    -   Image: `nginx`
    -   Mount `exam-pvc` at `/usr/share/nginx/html`

### Success Criteria

```bash
kubectl get pv exam-pv
# STATUS = Bound
kubectl get pvc exam-pvc
# STATUS = Bound
kubectl get pod storage-pod
# STATUS = Running
```

------------------------------------------------------------------------

## Task 15 — JSONPath and Custom Output (7%)

### Task

Using `kubectl` and JSONPath expressions:

1.  Save the **InternalIP** of every cluster node to
    **`/opt/node-ips.txt`** (one IP per line).

2.  Save the **names of all pods** in the `kube-system` namespace,
    **sorted by `.metadata.creationTimestamp`** (oldest first), to
    **`/opt/sorted-pods.txt`** (one name per line).

### Success Criteria

```bash
cat /opt/node-ips.txt
# Lists IPs (e.g., 10.0.0.2\n10.0.0.3)

cat /opt/sorted-pods.txt
# Lists kube-system pod names sorted by age
```

------------------------------------------------------------------------

## Final Completion Criteria

You have successfully completed the exam when:

-   All 15 tasks pass the validation script (`validate-cluster.sh`).
-   Both nodes are in `Ready` state.
-   All kube-system pods are healthy.
-   etcd backup and restore operations completed successfully.
-   Workloads, networking, storage, and RBAC are correctly configured.

### Scoring Summary

| # | Task                              | Weight |
|---|-----------------------------------|--------|
| 1 | etcd Snapshot Backup              | 7%     |
| 2 | etcd Snapshot Restore             | 7%     |
| 3 | Fix Broken Worker Node            | 8%     |
| 4 | Drain and Uncordon Node           | 5%     |
| 5 | Create DaemonSet                  | 5%     |
| 6 | Multi-container Pod               | 7%     |
| 7 | Rolling Update & Rollback         | 5%     |
| 8 | Scale + Resource Limits           | 5%     |
| 9 | Create NodePort Service           | 5%     |
| 10| Node Affinity Scheduling          | 5%     |
| 11| Container Log Extraction          | 5%     |
| 12| ServiceAccount + RBAC             | 8%     |
| 13| NetworkPolicy                     | 8%     |
| 14| PV + PVC + Pod                    | 8%     |
| 15| JSONPath / Custom Output          | 7%     |
|   | **Total**                         |**100%**|
