# Practice Exam 3 — Study Guide & Reference

> Concept summaries, diagnostic steps, and official documentation links for each task.

------------------------------------------------------------------------

## Task 1 — etcd Snapshot Backup

### Concept

etcd is the key-value store that holds all cluster state — every object you create with `kubectl` lives here. Backing it up is the single most critical disaster recovery operation for a Kubernetes cluster. The CKA exam expects you to know the `etcdctl snapshot save` command and the TLS flags required to authenticate against etcd.

### Key Docs

- [Backing up an etcd cluster](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [Operating etcd clusters for Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/)

### Diagnostic Steps

```bash
# 1. Confirm etcdctl is available
which etcdctl
ETCDCTL_API=3 etcdctl version

# 2. Find etcd TLS flags from the running static pod
cat /etc/kubernetes/manifests/etcd.yaml | grep -E 'cert-file|key-file|trusted-ca'

# 3. Test connectivity to etcd
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Corrective Steps

```bash
# Take the snapshot
ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db --write-out=table
```

------------------------------------------------------------------------

## Task 2 — etcd Snapshot Restore

### Concept

Restoring etcd from a snapshot recovers the entire cluster state to the point-in-time the snapshot was taken. The restore operation writes to a **new data directory** — it does not overwrite the existing one in-place. In a real scenario you would then update the etcd static pod manifest to point at the new directory and restart etcd.

### Key Docs

- [Restoring an etcd cluster](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#restoring-an-etcd-cluster)
- [etcdctl snapshot restore reference](https://etcd.io/docs/v3.5/op-guide/recovery/)

### Diagnostic Steps

```bash
# 1. Verify snapshot file exists and is valid
ls -lh /opt/etcd-pre-break.db
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-pre-break.db --write-out=table
```

### Corrective Steps

```bash
# Restore to a new data directory
ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-pre-break.db \
  --data-dir=/var/lib/etcd-restored

# Verify restore produced the expected structure
ls /var/lib/etcd-restored/member/
# Should contain: snap/  wal/
```

> **Exam tip:** If the task asks you to make the cluster use the restored data, you'd edit `/etc/kubernetes/manifests/etcd.yaml` and change the `--data-dir` flag and the corresponding `hostPath` volume to point at `/var/lib/etcd-restored`.

------------------------------------------------------------------------

## Task 3 — Fix a Broken Worker Node

### Concept

The kubelet is the node-level agent that registers the node with the API server and manages pod lifecycle. If kubelet is stopped, misconfigured, or missing its config file, the node goes `NotReady`. This is the most common node troubleshooting scenario on the CKA.

### Key Docs

- [Troubleshooting clusters — Worker Nodes](https://kubernetes.io/docs/tasks/debug/debug-cluster/#worker-nodes)
- [kubelet configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)
- [kubeadm kubelet integration](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/)

### Diagnostic Steps

```bash
# 1. From control plane, identify the problem node
kubectl get nodes
kubectl describe node <worker>   # look at Conditions section

# 2. SSH to the worker
ssh root@<worker-ip>

# 3. Check kubelet status and logs
systemctl status kubelet
journalctl -u kubelet --no-pager -n 50

# 4. Check kubelet config exists
ls -la /var/lib/kubelet/config.yaml
cat /var/lib/kubelet/kubeadm-flags.env
```

### Corrective Steps

```bash
# Common fixes:
# a) Config file missing or renamed — restore it
mv /var/lib/kubelet/config.yaml.broken /var/lib/kubelet/config.yaml

# b) Kubelet disabled — re-enable and start
systemctl enable kubelet
systemctl start kubelet

# c) Verify recovery
systemctl status kubelet
# Back on control plane:
kubectl get nodes   # should show Ready
```

------------------------------------------------------------------------

## Task 4 — Drain and Uncordon a Node

### Concept

`kubectl drain` gracefully evicts all pods from a node, making it safe for maintenance. The node is automatically **cordoned** (marked `SchedulingDisabled`). After maintenance, `kubectl uncordon` makes it schedulable again. This is routine work for OS patching, kernel upgrades, or hardware replacement.

### Key Docs

- [Safely drain a node](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/)
- [kubectl drain reference](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_drain/)
- [kubectl cordon/uncordon](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_cordon/)

### Diagnostic Steps

```bash
# Check current node status
kubectl get nodes
# Look for SchedulingDisabled in STATUS column

# See what pods are running on the worker
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=<worker>
```

### Corrective Steps

```bash
# 1. Drain the node (evict workloads, skip DaemonSets)
kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data

# 2. Perform maintenance (SSH and do work)
ssh root@<worker-ip>
touch /opt/maintenance-complete
exit

# 3. Uncordon the node
kubectl uncordon <worker>

# 4. Verify
kubectl get nodes   # no SchedulingDisabled
```

------------------------------------------------------------------------

## Task 5 — Create a DaemonSet

### Concept

A DaemonSet ensures exactly one copy of a pod runs on every (or selected) node. Common uses: log collectors, monitoring agents, network plugins. To run on control-plane nodes, you must add a toleration for the `node-role.kubernetes.io/control-plane:NoSchedule` taint.

### Key Docs

- [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

### Diagnostic Steps

```bash
# Check if DaemonSet exists and its status
kubectl get ds -n monitoring
kubectl describe ds log-collector -n monitoring

# Check if pods landed on all nodes
kubectl get pods -n monitoring -o wide

# If not on control-plane, check taints
kubectl describe node <control-plane> | grep Taints
```

### Corrective Steps

```yaml
# Create namespace if needed
kubectl create namespace monitoring

# Create the DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: log-collector
  template:
    metadata:
      labels:
        app: log-collector
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: collector
        image: busybox
        command: ["sh", "-c", "while true; do echo collecting-logs; sleep 60; done"]
```

> **Exam tip:** Generate the YAML skeleton with `kubectl create daemonset log-collector --image=busybox -n monitoring --dry-run=client -o yaml > ds.yaml`, then add tolerations and command.

------------------------------------------------------------------------

## Task 6 — Multi-container Pod with Init Container

### Concept

Pods can contain multiple containers that share networking and storage. **Init containers** run to completion before any main containers start — use them for setup tasks. **Sidecar containers** run alongside the main container for cross-cutting concerns (logging, proxying). The CKA frequently tests whether you can compose a pod spec with init + main + sidecar containers sharing a volume.

### Key Docs

- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Multi-container Pods (Sidecar pattern)](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- [Volumes — emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)

### Diagnostic Steps

```bash
# Check pod status
kubectl get pod multi-pod
kubectl describe pod multi-pod

# Check init container status specifically
kubectl get pod multi-pod -o jsonpath='{.status.initContainerStatuses[*].ready}'

# Check logs of each container
kubectl logs multi-pod -c init-data
kubectl logs multi-pod -c app
kubectl logs multi-pod -c monitor
```

### Corrective Steps

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-pod
spec:
  volumes:
  - name: shared-data
    emptyDir: {}
  initContainers:
  - name: init-data
    image: busybox
    command: ["sh", "-c", "echo ready > /data/status"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "cat /data/status && sleep 3600"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: monitor
    image: busybox
    command: ["sh", "-c", "while true; do echo monitoring; sleep 10; done"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
```

------------------------------------------------------------------------

## Task 7 — Rolling Update and Rollback

### Concept

Deployments use a rolling update strategy by default: new pods are created before old ones are terminated, ensuring zero-downtime upgrades. Every change to the pod template creates a new **revision** tracked in rollout history. `kubectl rollout undo` reverts to the previous revision. This is a bread-and-butter CKA skill.

### Key Docs

- [Performing a Rolling Update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [Deployments — Updating](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment)
- [Deployments — Rolling Back](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-back-a-deployment)

### Diagnostic Steps

```bash
# Check current image
kubectl get deployment rollout-app -o jsonpath='{.spec.template.spec.containers[0].image}'

# Watch rollout progress
kubectl rollout status deployment rollout-app

# View revision history
kubectl rollout history deployment rollout-app
```

### Corrective Steps

```bash
# 1. Update the image
kubectl set image deployment/rollout-app web=nginx:1.25.0

# 2. Wait for rollout to complete
kubectl rollout status deployment/rollout-app

# 3. Rollback to previous revision
kubectl rollout undo deployment/rollout-app

# 4. Verify
kubectl get deployment rollout-app -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should be nginx:1.24.0
```

------------------------------------------------------------------------

## Task 8 — Scale a Deployment and Configure Resources

### Concept

Scaling adjusts the replica count of a deployment. Resource **requests** tell the scheduler how much CPU/memory to reserve; **limits** cap how much a container can use. Setting these correctly prevents over-provisioning and OOM kills. The CKA tests both imperative scaling and declarative resource configuration.

### Key Docs

- [Scaling a Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#scaling-a-deployment)
- [Resource Management for Pods](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [LimitRange](https://kubernetes.io/docs/concepts/policy/limit-range/)

### Diagnostic Steps

```bash
# Check current replicas and resources
kubectl get deployment scale-app
kubectl get deployment scale-app -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

### Corrective Steps

```bash
# 1. Scale to 4 replicas
kubectl scale deployment scale-app --replicas=4

# 2. Set resource requests and limits
kubectl set resources deployment scale-app \
  --requests=cpu=50m,memory=64Mi \
  --limits=cpu=200m,memory=128Mi

# 3. Verify
kubectl get deployment scale-app
kubectl get deployment scale-app -o yaml | grep -A6 resources
```

------------------------------------------------------------------------

## Task 9 — Create a NodePort Service

### Concept

A **NodePort** Service exposes a set of pods on a static port on every node's IP. External traffic hits `<NodeIP>:<NodePort>` and gets forwarded to pods matching the selector. NodePort is the foundation for external access without a cloud load balancer — especially relevant on bare-metal clusters like yours.

### Key Docs

- [Service — NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)
- [kubectl expose reference](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_expose/)

### Diagnostic Steps

```bash
# Check existing services
kubectl get svc

# Verify the deployment has the right labels
kubectl get deployment backend-app --show-labels
kubectl get pods -l app=backend

# Test connectivity
curl http://<node-ip>:30080
```

### Corrective Steps

```bash
# Option A — imperative
kubectl expose deployment backend-app \
  --name=backend-svc \
  --type=NodePort \
  --port=80 \
  --target-port=80

# Then patch nodePort (if a specific port is required)
kubectl patch svc backend-svc --type='json' \
  -p='[{"op":"replace","path":"/spec/ports/0/nodePort","value":30080}]'

# Option B — declarative YAML
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  type: NodePort
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

------------------------------------------------------------------------

## Task 10 — Schedule a Pod with Node Affinity

### Concept

**Node affinity** is the declarative replacement for `nodeSelector`. It lets you express scheduling rules like "only run on nodes with label `disk=ssd`" with either hard requirements (`requiredDuringScheduling`) or soft preferences (`preferredDuringScheduling`). The CKA tests the `required` variant.

### Key Docs

- [Assigning Pods to Nodes — Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity)
- [Affinity and Anti-affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

### Diagnostic Steps

```bash
# Check node labels
kubectl get nodes --show-labels
kubectl get node <worker> -L disk

# Check if pod is pending (scheduling failure)
kubectl describe pod affinity-pod | grep -A5 Events
```

### Corrective Steps

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: affinity-pod
spec:
  containers:
  - name: web
    image: nginx
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values:
            - ssd
```

> **Exam tip:** You can't generate affinity YAML with `kubectl run`. Use `kubectl run affinity-pod --image=nginx --dry-run=client -o yaml > pod.yaml` to get the skeleton, then add the affinity block manually.

------------------------------------------------------------------------

## Task 11 — Retrieve and Save Container Logs

### Concept

`kubectl logs` streams stdout/stderr from a container. In the CKA you're often asked to extract specific log lines (by level, pattern, or time range) and save them to a file. This tests your familiarity with `kubectl logs` combined with standard Unix text processing (`grep`).

### Key Docs

- [kubectl logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)
- [Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)

### Diagnostic Steps

```bash
# Check pod exists and is running
kubectl get pod log-generator

# View all logs
kubectl logs log-generator

# See how many lines of each level
kubectl logs log-generator | grep -c ERROR
kubectl logs log-generator | grep -c INFO
```

### Corrective Steps

```bash
# Extract only ERROR lines and save
kubectl logs log-generator | grep ERROR > /opt/error-logs.txt

# Verify
cat /opt/error-logs.txt
grep -c INFO /opt/error-logs.txt   # should be 0
```

------------------------------------------------------------------------

## Task 12 — Create ServiceAccount and RBAC

### Concept

Kubernetes RBAC controls **who** (subject) can do **what** (verbs) on **which resources** (API objects). A **ClusterRole** defines permissions cluster-wide; a **ClusterRoleBinding** grants those permissions to a subject. Unlike a Role/RoleBinding (namespace-scoped), ClusterRole+ClusterRoleBinding allows access across all namespaces. The CKA frequently tests creation of the full chain: ServiceAccount → ClusterRole → ClusterRoleBinding.

### Key Docs

- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [ServiceAccounts](https://kubernetes.io/docs/concepts/security/service-accounts/)
- [kubectl create clusterrole](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_clusterrole/)
- [kubectl create clusterrolebinding](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_clusterrolebinding/)

### Diagnostic Steps

```bash
# Check if SA exists
kubectl get sa deploy-bot -n dev-team

# Check ClusterRole
kubectl get clusterrole pod-reader
kubectl describe clusterrole pod-reader

# Check binding
kubectl get clusterrolebinding pod-reader-binding
kubectl describe clusterrolebinding pod-reader-binding

# Test permissions
kubectl auth can-i list pods --as=system:serviceaccount:dev-team:deploy-bot
kubectl auth can-i list pods --as=system:serviceaccount:dev-team:deploy-bot -n kube-system
```

### Corrective Steps

```bash
# 1. Create ServiceAccount
kubectl create serviceaccount deploy-bot -n dev-team

# 2. Create ClusterRole
kubectl create clusterrole pod-reader \
  --verb=get,list,watch \
  --resource=pods

# 3. Create ClusterRoleBinding
kubectl create clusterrolebinding pod-reader-binding \
  --clusterrole=pod-reader \
  --serviceaccount=dev-team:deploy-bot

# 4. Verify
kubectl auth can-i list pods --as=system:serviceaccount:dev-team:deploy-bot
# yes
```

> **Exam tip:** Imperative `kubectl create` commands are faster than writing YAML for RBAC. Know the `--serviceaccount=namespace:name` syntax.

------------------------------------------------------------------------

## Task 13 — Create a NetworkPolicy

### Concept

NetworkPolicies control traffic flow at the IP/port level for pods. By default, all traffic is allowed. A NetworkPolicy with a `podSelector` applies to matching pods, and its `ingress`/`egress` rules define what traffic is permitted. Any traffic not explicitly allowed by a matching policy is **denied**. The CKA tests your ability to write policies that allow traffic from specific namespaces or pods while blocking everything else.

### Key Docs

- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)

### Diagnostic Steps

```bash
# Check existing policies
kubectl get networkpolicy -n web-app

# Check namespace labels (used in namespaceSelector)
kubectl get namespace api-backend --show-labels

# Check pod labels
kubectl get pods -n web-app --show-labels
```

### Corrective Steps

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-only
  namespace: web-app
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: backend
```

> **Exam tip:** Remember that once *any* NetworkPolicy selects a pod, all traffic not explicitly allowed is denied. If you only list `Ingress` in `policyTypes`, egress remains unrestricted.

------------------------------------------------------------------------

## Task 14 — Create PersistentVolume, PVC, and Mount in Pod

### Concept

The Kubernetes storage model separates **provisioning** (PV) from **consumption** (PVC). A PV represents a piece of storage in the cluster. A PVC is a request for storage that binds to a matching PV by access mode, capacity, and StorageClass. Pods reference PVCs in their volume spec. On bare-metal clusters, `hostPath` PVs are the simplest option.

### Key Docs

- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Configure a Pod to Use a PersistentVolume](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/)

### Diagnostic Steps

```bash
# Check PV/PVC status
kubectl get pv
kubectl get pvc

# If PVC is Pending, check events
kubectl describe pvc exam-pvc

# Common mismatches: storageClassName, accessModes, capacity
```

### Corrective Steps

```yaml
# 1. PersistentVolume
apiVersion: v1
kind: PersistentVolume
metadata:
  name: exam-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: /mnt/exam-data
---
# 2. PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: exam-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
---
# 3. Pod using the PVC
apiVersion: v1
kind: Pod
metadata:
  name: storage-pod
spec:
  containers:
  - name: web
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: exam-pvc
```

> **Exam tip:** PVC `requests.storage` must be ≤ PV `capacity.storage`, `accessModes` must match, and `storageClassName` must match exactly. A PVC requesting `500Mi` will bind to a `1Gi` PV.

------------------------------------------------------------------------

## Task 15 — JSONPath and Custom Output

### Concept

`kubectl` supports **JSONPath** expressions to extract specific fields from resource objects. The CKA tests this to confirm you can query cluster state programmatically. Sorting by fields like `creationTimestamp` uses `--sort-by`. These skills are essential for scripting and exam time-saving.

### Key Docs

- [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/)
- [kubectl output formatting](https://kubernetes.io/docs/reference/kubectl/#custom-columns)
- [kubectl get --sort-by](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/)

### Diagnostic Steps

```bash
# Explore the JSON structure of a node
kubectl get nodes -o json | head -80

# Find the path to InternalIP
kubectl get nodes -o jsonpath='{.items[*].status.addresses}'

# Explore pod metadata
kubectl get pods -n kube-system -o json | jq '.items[0].metadata.creationTimestamp'
```

### Corrective Steps

```bash
# Task 15a — Node IPs (one per line)
kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' \
  > /opt/node-ips.txt

# Task 15b — kube-system pods sorted by creation time
kubectl get pods -n kube-system \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
  > /opt/sorted-pods.txt

# Verify
cat /opt/node-ips.txt
cat /opt/sorted-pods.txt
```

> **Exam tip:** Practice the `{range .items[*]}...{end}` pattern — it shows up in nearly every JSONPath exam question. Use `{"\n"}` to get one result per line.

------------------------------------------------------------------------

## General CKA Exam Tips

1. **Bookmark the docs.** You have access to `kubernetes.io/docs` during the exam. Pre-bookmark the pages linked above.
2. **Use imperative commands.** `kubectl create`, `kubectl expose`, `kubectl run --dry-run=client -o yaml` save enormous time vs writing YAML from scratch.
3. **Set aliases early.** `alias k=kubectl` and `export do="--dry-run=client -o yaml"` at the start of the exam.
4. **Fix infrastructure first.** If a node is down, fix it before attempting workload tasks — many tasks depend on a healthy cluster.
5. **Read the task weight.** Prioritize high-percentage tasks. Don't spend 20 minutes on a 4% task.
6. **Use `kubectl explain`.** `kubectl explain pod.spec.affinity.nodeAffinity` gives you the field structure without leaving the terminal.
7. **Verify after every task.** Run the success criteria command from the task description before moving on.
