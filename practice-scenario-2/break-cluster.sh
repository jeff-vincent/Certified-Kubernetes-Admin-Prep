#!/usr/bin/env bash
set -euo pipefail

echo "🚨 Breaking the cluster (Scenario 02)..."
echo

########################################
# Discover nodes
########################################
CONTROL_PLANE_NODE=$(kubectl get nodes --no-headers | awk '$3 ~ /control-plane/ {print $1}')
WORKER_NODE=$(kubectl get nodes --no-headers | awk '$3 !~ /control-plane/ {print $1}')

WORKER_IP=$(kubectl get node "$WORKER_NODE" \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

SSH_OPTS="-o StrictHostKeyChecking=no"

echo "🧠 Control plane: $CONTROL_PLANE_NODE"
echo "🧱 Worker:        $WORKER_NODE ($WORKER_IP)"
echo

########################################
# 1. Break kubelet config (NOT stop)
########################################
echo "🔧 [1/6] Breaking kubelet configuration"

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
sed -i 's/^KUBELET_EXTRA_ARGS=.*/KUBELET_EXTRA_ARGS=--fail-swap-on=false --node-ip=192.0.2.123/' \
  /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet
EOF

########################################
# 2. Break CNI consistency
########################################
echo "🌐 [2/6] Creating CNI mismatch"

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
rm -f /opt/cni/bin/flannel
EOF

########################################
# 3. Break CoreDNS
########################################
echo "📛 [3/6] Breaking CoreDNS configuration"

kubectl -n kube-system get configmap coredns -o yaml \
  | sed 's/forward .*/forward . 0.0.0.0/' \
  | kubectl apply -f -

########################################
# 4. Broken RBAC (wrong scope)
########################################
echo "🔐 [4/6] Creating broken RBAC (namespace vs cluster)"

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
  name: pod-reader
  namespace: kube-system
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: kube-system
subjects:
- kind: ServiceAccount
  name: broken-app
  namespace: default
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

########################################
# 5. Image pull failure
########################################
echo "💥 [5/6] Deploying image pull failure"

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
        image: busybox:nonexistent
        command: ["sh", "-c", "sleep 3600"]
EOF

########################################
# 6. StorageClass mismatch
########################################
echo "💾 [6/6] Breaking PVC via StorageClass mismatch"

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
  storageClassName: slow
  hostPath:
    path: /mnt/data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: fast
EOF

echo
echo "✅ Scenario 02 cluster broken."
