#!/usr/bin/env bash
set -euo pipefail

echo "🚨 Breaking the cluster (intentionally)..."
echo

########################################
# Discover worker node + IP dynamically
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
# 1. Stop kubelet on the worker node
########################################
echo "🔧 [1/6] Stopping kubelet on worker node"

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
systemctl stop kubelet
systemctl disable kubelet
EOF

########################################
# 2. Break CNI on the worker node
########################################
echo "🌐 [2/6] Breaking CNI configuration on worker node"

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
if [ -d /etc/cni/net.d ]; then
  mkdir -p /root/cni-backup
  mv /etc/cni/net.d/* /root/cni-backup/ || true
fi
EOF

########################################
# Ensure API server is reachable before kubectl steps
########################################
kubectl get --raw=/healthz >/dev/null 2>&1 || {
  echo "❌ API server is not reachable; aborting"
  exit 1
}

########################################
# 3. Create broken RBAC configuration
########################################
echo "🔐 [3/6] Creating broken RBAC configuration"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: broken-app
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: broken-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: broken-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: broken-app
  namespace: default
roleRef:
  kind: Role
  name: broken-role
  apiGroup: rbac.authorization.k8s.io
EOF

########################################
# 4. Deploy a crashing workload
########################################
echo "💥 [4/6] Deploying crashing workload"

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crashy-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crashy
  template:
    metadata:
      labels:
        app: crashy
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sh", "-c", "sleep 5 && exit 1"]
        livenessProbe:
          exec:
            command: ["false"]
          initialDelaySeconds: 2
          periodSeconds: 5
EOF

########################################
# 5. Create broken PV and PVC
########################################
echo "💾 [5/6] Creating broken PV and PVC"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: broken-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  hostPath:
    path: /mnt/does-not-exist
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
EOF

########################################
# 6. Break kube-apiserver static pod (LAST)
########################################
echo "🧠 [6/6] Misconfiguring kube-apiserver manifest"

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

if ! grep -q "12379" "$APISERVER_MANIFEST"; then
  cp "$APISERVER_MANIFEST" "${APISERVER_MANIFEST}.bak"
  sed -i 's|--etcd-servers=.*|--etcd-servers=https://127.0.0.1:12379|' "$APISERVER_MANIFEST"
fi

echo
echo "✅ Cluster successfully broken."
echo "👉 Proceed to the practice tasks to repair it."
