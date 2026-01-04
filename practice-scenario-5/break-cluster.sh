

echo "🚨 Breaking cluster — Scenario 05 (Stateful + Networking)"


# Create blocking NetworkPolicy
kubectl apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
name: deny-all
spec:
podSelector: {}
policyTypes:
- Ingress
- Egress
EOF


# StatefulSet with broken volume mount
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
name: broken-stateful
spec:
serviceName: broken
replicas: 1
selector:
matchLabels:
app: broken
template:
metadata:
labels:
app: broken
spec:
containers:
- name: app
image: busybox
command: ["sh", "-c", "sleep 3600"]
volumeMounts:
- name: data
mountPath: /data
volumeClaimTemplates:
- metadata:
name: data
spec:
accessModes: ["ReadWriteOnce"]
resources:
requests:
storage: 1Gi
storageClassName: nonexistent
EOF


echo "✅ Scenario 05 broken"
