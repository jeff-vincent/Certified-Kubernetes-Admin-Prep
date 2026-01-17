#!/usr/bin/env bash
set -euo pipefail

echo "🚨 Breaking the cluster (intentionally)..."
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
# 1. Break kubelet on worker
########################################
echo "🔧 [1/8] Breaking kubelet on worker node"

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
systemctl stop kubelet
systemctl disable kubelet
EOF

########################################
# 2. Break CNI on worker
########################################
echo "🌐 [2/8] Breaking CNI configuration on worker node"

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
# 3. Break RBAC
########################################
echo "🔐 [3/8] Creating broken RBAC configuration"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: exam-app
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: exam-role
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]   # Missing "list"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: exam-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: exam-app
  namespace: default
roleRef:
  kind: Role
  name: exam-role
  apiGroup: rbac.authorization.k8s.io
EOF

########################################
# 4. Deploy broken workload
########################################
echo "💥 [4/8] Deploying broken workload"

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exam-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: exam
  template:
    metadata:
      labels:
        app: exam
    spec:
      serviceAccountName: exam-app
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
# 5. Break ConfigMap usage
########################################
echo "📄 [5/8] Creating broken ConfigMap + Pod"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: exam-config
  namespace: default
data:
  MESSAGE: "Hello CKA"
---
apiVersion: v1
kind: Pod
metadata:
  name: config-broken
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo $MESSAGE && sleep 3600"]
    env:
    - name: MESSAGE
      valueFrom:
        configMapKeyRef:
          name: missing-config   # WRONG NAME
          key: MESSAGE
EOF

########################################
# 6. Break Service/CoreDNS
########################################
echo "🌍 [6/8] Breaking Service + DNS"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: exam-service
spec:
  selector:
    app: non-existent   # Wrong selector
  ports:
  - port: 80
    targetPort: 8080
EOF

########################################
# 7. Break Storage
########################################
echo "💾 [7/8] Creating broken PV/PVC"

kubectl apply -f - <<'EOF'
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
    path: /mnt/does-not-exist
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: exam-pvc
spec:
  accessModes:
    - ReadWriteMany   # Mismatch
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
EOF

########################################
# 8. Break kube-apiserver static pod (LAST)
########################################
echo "🧠 [8/8] Misconfiguring kube-apiserver manifest"

APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

if ! grep -q "12379" "$APISERVER_MANIFEST"; then
  cp "$APISERVER_MANIFEST" "${APISERVER_MANIFEST}.bak"
  sed -i 's|--etcd-servers=.*|--etcd-servers=https://127.0.0.1:12379|' "$APISERVER_MANIFEST"
fi

echo
echo "✅ Cluster successfully broken."
echo "👉 Proceed to the practice tasks."
