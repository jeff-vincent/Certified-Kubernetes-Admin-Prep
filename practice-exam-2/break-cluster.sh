#!/usr/bin/env bash
set -euo pipefail

echo "🚨 Breaking the cluster (Scenario 2)..."
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
# 1. Break container runtime on worker
########################################
echo "🐳 [1/8] Breaking container runtime on worker"

ssh $SSH_OPTS root@"$WORKER_IP" <<'EOF'
systemctl stop containerd
systemctl disable containerd
EOF

########################################
# 2. Break kube-proxy on worker
########################################
echo "🕸️ [2/8] Breaking kube-proxy on worker"

kubectl -n kube-system delete ds kube-proxy --wait=false

########################################
# Ensure API server is reachable
########################################
kubectl get --raw=/healthz >/dev/null 2>&1 || {
  echo "❌ API server is not reachable; aborting"
  exit 1
}

########################################
# 3. Break kube-scheduler static pod
########################################
echo "📅 [3/8] Misconfiguring kube-scheduler manifest"

SCHED_MANIFEST="/etc/kubernetes/manifests/kube-scheduler.yaml"

ssh $SSH_OPTS root@"$CONTROL_PLANE_NODE" <<EOF
if ! grep -q "leader-elect=false" "$SCHED_MANIFEST"; then
  cp "$SCHED_MANIFEST" "${SCHED_MANIFEST}.bak"
  sed -i 's|leader-elect=true|leader-elect=false|' "$SCHED_MANIFEST"
fi
EOF

########################################
# 4. Break RBAC (ClusterRoleBinding)
########################################
echo "🔐 [4/8] Creating broken RBAC"

# 🔧 FIX: Create the namespace first
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ops-audit
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get"]   # Still intentionally missing "list"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: node-reader-binding
subjects:
- kind: ServiceAccount
  name: ops-audit
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
EOF


########################################
# 5. Deploy broken StatefulSet
########################################
echo "💾 [5/8] Deploying broken StatefulSet"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  selector:
    app: db
  ports:
  - port: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: postgres-wrong   # WRONG
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: db
        image: busybox
        command: ["sh", "-c", "sleep 3600"]
EOF

########################################
# 6. Break Secret usage
########################################
echo "🔑 [6/8] Creating broken Secret + Pod"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  API_KEY: $(echo -n "supersecret" | base64)
---
apiVersion: v1
kind: Pod
metadata:
  name: secret-consumer
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "echo $API_KEY && sleep 3600"]
    env:
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: missing-secret   # WRONG NAME
          key: API_KEY
EOF

########################################
# 7. Break Ingress
########################################
echo "🌐 [7/8] Creating broken Ingress"

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
  - host: web.example.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wrong-backend   # WRONG
            port:
              number: 80
EOF

########################################
# 8. Break Storage
########################################
echo "💽 [8/8] Creating broken StorageClass/PVC"

kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow-disk
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: fast-disk   # MISMATCH
  hostPath:
    path: /mnt/app-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: slow-disk
EOF

echo
echo "✅ Cluster successfully broken."
echo "👉 Proceed to Scenario 2 practice tasks."
