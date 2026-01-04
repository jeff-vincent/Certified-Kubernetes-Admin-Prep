#!/usr/bin/env bash
set -euo pipefail

WORKER_NODE="worker"
WORKER_HOST="worker"   # DNS or /etc/hosts entry
SSH_OPTS="-o StrictHostKeyChecking=no"

echo "🚨 Breaking the cluster (intentionally)..."

########################################
# 1. Stop kubelet on the worker node
########################################
echo "🔧 [1/6] Stopping kubelet on worker node"
ssh $SSH_OPTS root@$WORKER_HOST <<'EOF'
systemctl stop kubelet
systemctl disable kubelet
EOF

########################################
# 2. Break CNI on the worker node
########################################
echo "🌐 [2/6] Breaking CNI configuration on worker"
ssh $SSH_OPTS root@$WORKER_HOST <<'EOF'
if [ -d /etc/cni/net.d ]; then
  mkdir -p /root/cni-backup
  mv /etc/cni/net.d/* /root/cni-backup/ || true
fi
EOF

########################################
# 3. Break kube-apiserver static pod
########################################
echo "🧠 [3/6] Misconfiguring kube-apiserver manifest"

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

if ! grep -q "invalid-etcd-endpoint" "$APISERVER_MANIFEST"; then
  cp "$APISERVER_MANIFEST" /etc/kubernetes/manifests/kube-apiserver.yaml.bak
  sed -i 's|--etcd-servers=.*|--etcd-servers=https://127.0.0.1:12379|' "$APISERVER_MANIFEST"
fi

########################################
# 4. Break RBAC for an app
########################################
echo "🔐 [4/6] Creating broken RBAC setup"

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
roleRef:
  kind: Role
  name: broken-role
  apiGroup: rbac.authorization.k8s.io
EOF

########################################
# 5. Deploy a crashing workload
########################################
echo "💥 [5/6] Deploying crashing workload"

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
# 6. Break PersistentVolume binding
########################################
echo "💾 [6/6] Creating broken PV/PVC"

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

echo
echo "✅ Cluster successfully broken."
echo "👉 Proceed to the practice tasks to repair it."

