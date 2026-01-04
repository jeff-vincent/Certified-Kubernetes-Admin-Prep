#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "❌ FAIL: $1"
  exit 1
}

pass() {
  echo "✅ PASS: $1"
}

echo "🔎 Validating Kubernetes cluster state..."
echo

########################################
# 1. Nodes are Ready
########################################
NOT_READY=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}')
if [[ -n "$NOT_READY" ]]; then
  fail "Some nodes are NotReady: $NOT_READY"
fi
pass "All nodes are Ready"

########################################
# 2. kube-system pods are healthy
########################################
BAD_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers | grep -Ev 'Running|Completed' || true)
if [[ -n "$BAD_SYSTEM_PODS" ]]; then
  fail "Some kube-system pods are unhealthy"
fi
pass "kube-system pods healthy"

########################################
# 3. API server is stable
########################################
kubectl get --raw=/healthz >/dev/null 2>&1 \
  || fail "API server health check failed"
pass "API server responding normally"

########################################
# 4. RBAC allows expected access
########################################
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:broken-app \
  >/dev/null 2>&1 \
  || fail "RBAC still blocking pod list access"
pass "RBAC permissions corrected"

########################################
# 5. crashy-app is healthy
########################################
READY_REPLICAS=$(kubectl get deploy crashy-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "$READY_REPLICAS" != "1" ]]; then
  fail "crashy-app is not running successfully"
fi
pass "Application deployment healthy"

########################################
# 6. PVC is Bound
########################################
PVC_PHASE=$(kubectl get pvc broken-pvc -o jsonpath='{.status.phase}')
if [[ "$PVC_PHASE" != "Bound" ]]; then
  fail "PVC is not Bound"
fi
pass "PersistentVolumeClaim bound successfully"

echo
echo "🎉 Cluster validation PASSED — great job!"

