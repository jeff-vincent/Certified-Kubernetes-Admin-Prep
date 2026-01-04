#!/usr/bin/env bash
set -euo pipefail


echo "🚨 Breaking cluster — Scenario 04 (Scheduling)"


# Taint worker node
WORKER=$(kubectl get nodes --no-headers | awk '$3 !~ /control-plane/ {print $1}')


kubectl taint nodes "$WORKER" key=value:NoSchedule --overwrite


# Deploy unschedulable pod
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
name: pending-pod
spec:
containers:
- name: app
image: busybox
command: ["sh", "-c", "sleep 3600"]
resources:
requests:
cpu: "10"
memory: "10Gi"
EOF


echo "✅ Scenario 04 broken"
