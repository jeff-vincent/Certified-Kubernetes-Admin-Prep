#!/usr/bin/env bash
set -euo pipefail

echo "🚨 Setting up Practice Exam 3 — Comprehensive CKA Gaps..."
echo

########################################
# Discover nodes dynamically
########################################
CONTROL_PLANE_NODE=$(kubectl get nodes --no-headers | awk '$3 ~ /control-plane/ {print $1}')
WORKER_NODE=$(kubectl get nodes --no-headers | awk '$3 !~ /control-plane/ {print $1}')

if [[ -z "$WORKER_NODE" ]]; then
  echo "❌ Could not determine worker node"
  kubectl get nodes -o wide
  exit 1
fi

WORKER_IP=$(kubectl get node "$WORKER_NODE" \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

if [[ -z "$WORKER_IP" ]]; then
  echo "❌ Could not determine worker node IP"
  kubectl get node "$WORKER_NODE" -o wide
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no"

echo "🧠 Control plane node: $CONTROL_PLANE_NODE"
echo "🧱 Worker node:        $WORKER_NODE ($WORKER_IP)"
echo

########################################
# 0. Install etcdctl for student use
########################################
echo "🔧 [0/10] Installing etcdctl on control plane..."

if ! command -v etcdctl &>/dev/null; then
  ETCD_VERSION="v3.5.12"
  curl -sL "https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz" \
    | tar xz --strip-components=1 -C /usr/local/bin/ "etcd-${ETCD_VERSION}-linux-amd64/etcdctl"
  chmod +x /usr/local/bin/etcdctl
  echo "  ✓ etcdctl installed"
else
  echo "  ✓ etcdctl already available"
fi

########################################
# 1. Create etcd pre-break snapshot
#    (for Task 2 — etcd restore)
########################################
echo "📦 [1/10] Taking etcd snapshot for restore task..."

ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-pre-break.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 2>/dev/null

echo "  ✓ Snapshot saved to /opt/etcd-pre-break.db"

# Clean up any previous exam artifacts
rm -f /opt/etcd-backup.db
rm -rf /var/lib/etcd-restored
rm -f /opt/error-logs.txt /opt/node-ips.txt /opt/sorted-pods.txt

########################################
# 2. Create deployment for rollout task
#    (Task 7 — Rolling Update & Rollback)
########################################
echo "🔄 [2/10] Creating deployment for rolling update task..."

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rollout-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rollout
  template:
    metadata:
      labels:
        app: rollout
    spec:
      containers:
      - name: web
        image: nginx:1.24.0
        ports:
        - containerPort: 80
EOF

########################################
# 3. Create deployment for scaling task
#    (Task 8 — Scale + Resource Limits)
########################################
echo "📈 [3/10] Creating deployment for scaling task..."

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scale
  template:
    metadata:
      labels:
        app: scale
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
EOF

########################################
# 4. Create deployment for NodePort task
#    (Task 9 — NodePort Service)
########################################
echo "🌐 [4/10] Creating deployment for NodePort task..."

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
EOF

########################################
# 5. Label worker node for affinity task
#    (Task 10 — Node Affinity)
########################################
echo "🏷️  [5/10] Labeling worker node with disk=ssd..."

kubectl label node "$WORKER_NODE" disk=ssd --overwrite

########################################
# 6. Create log-generator pod on control-plane
#    (Task 11 — Container Logs)
#    Runs on control-plane so it's unaffected
#    by worker kubelet issues.
########################################
echo "📝 [6/10] Creating log-generator pod on control plane..."

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: log-generator
  namespace: default
spec:
  tolerations:
  - key: node-role.kubernetes.io/control-plane
    effect: NoSchedule
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  containers:
  - name: logger
    image: busybox
    command: ["sh", "-c"]
    args:
    - |
      i=0
      while true; do
        i=$((i+1))
        if [ $((i % 3)) -eq 0 ]; then
          echo "ERROR: something went wrong at iteration $i"
        elif [ $((i % 5)) -eq 0 ]; then
          echo "WARN: check system resources at iteration $i"
        else
          echo "INFO: healthy log line $i"
        fi
        sleep 1
      done
  restartPolicy: Always
EOF

########################################
# 7. Create namespaces and pods for
#    RBAC (Task 12) and NetworkPolicy (Task 13)
########################################
echo "🏗️  [7/10] Creating namespaces and precondition resources..."

# Namespace for RBAC task
kubectl create namespace dev-team --dry-run=client -o yaml | kubectl apply -f -

# Namespaces for NetworkPolicy task
kubectl create namespace web-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace api-backend --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace api-backend purpose=backend --overwrite

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  namespace: web-app
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: api-pod
  namespace: api-backend
  labels:
    app: api
spec:
  containers:
  - name: api
    image: nginx
    ports:
    - containerPort: 80
EOF

########################################
# 8. Create hostPath directory on worker
#    (Task 14 — PV + PVC + Pod)
########################################
echo "💾 [8/10] Creating hostPath directory on worker..."

ssh $SSH_OPTS root@"$WORKER_IP" "mkdir -p /mnt/exam-data"

########################################
# 9. Wait for core resources to schedule
########################################
echo "⏳ [9/10] Waiting for resources to stabilize..."

kubectl wait --for=condition=Available deployment/rollout-app --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=Available deployment/scale-app --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=Available deployment/backend-app --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=Ready pod/log-generator --timeout=60s 2>/dev/null || true

########################################
# 10. Break kubelet on worker — MUST BE LAST
#     (Task 3 — Fix Worker Node)
#
#     The kubelet config file is moved so
#     kubelet fails on restart. The student
#     must find and restore it.
########################################
echo "💥 [10/10] Breaking kubelet on worker node..."

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.bak
mv /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.broken
systemctl restart kubelet
EOF

# Clean any previous DaemonSet/monitoring namespace
kubectl delete namespace monitoring --ignore-not-found=true 2>/dev/null || true
# Clean any leftover exam resources from previous runs
kubectl delete pod multi-pod --ignore-not-found=true 2>/dev/null || true
kubectl delete pod affinity-pod --ignore-not-found=true 2>/dev/null || true
kubectl delete pod storage-pod --ignore-not-found=true 2>/dev/null || true
kubectl delete svc backend-svc --ignore-not-found=true 2>/dev/null || true
kubectl delete pvc exam-pvc --ignore-not-found=true 2>/dev/null || true
kubectl delete pv exam-pv --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrole pod-reader --ignore-not-found=true 2>/dev/null || true
kubectl delete clusterrolebinding pod-reader-binding --ignore-not-found=true 2>/dev/null || true
kubectl delete sa deploy-bot -n dev-team --ignore-not-found=true 2>/dev/null || true
kubectl delete networkpolicy allow-backend-only -n web-app --ignore-not-found=true 2>/dev/null || true
ssh $SSH_OPTS root@"$WORKER_IP" "rm -f /opt/maintenance-complete" 2>/dev/null || true

echo
echo "========================================="
echo "✅ Practice Exam 3 environment is ready."
echo "========================================="
echo
echo "📋 15 tasks — 120 minutes"
echo "📄 See: cka_practice_exam_3.md"
echo "✔️  Run: validate-cluster.sh when finished"
echo
echo "💡 Tip: The worker node is down."
echo "   Fix infrastructure issues before"
echo "   attempting workload tasks."
echo "========================================="
