
---

# ==========================================
# FILE 3 — Validator (`validate.sh`)
# ==========================================

```bash
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
# 1. Nodes Ready
########################################
NOT_READY=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}')
if [[ -n "$NOT_READY" ]]; then
  fail "Some nodes are NotReady: $NOT_READY"
fi
pass "All nodes are Ready"

########################################
# 2. kube-system healthy
########################################
BAD_SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers | grep -Ev 'Running|Completed' || true)
if [[ -n "$BAD_SYSTEM_PODS" ]]; then
  fail "Some kube-system pods are unhealthy"
fi
pass "kube-system pods healthy"

########################################
# 3. API server stable
########################################
kubectl get --raw=/healthz >/dev/null 2>&1 \
  || fail "API server health check failed"
pass "API server responding normally"

########################################
# 4. RBAC fixed
########################################
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:exam-app \
  >/dev/null 2>&1 \
  || fail "RBAC still blocking pod list access"
pass "RBAC permissions corrected"

########################################
# 5. exam-app healthy
########################################
READY_REPLICAS=$(kubectl get deploy exam-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "$READY_REPLICAS" != "1" ]]; then
  fail "exam-app is not running successfully"
fi
pass "Application deployment healthy"

########################################
# 6. ConfigMap pod running
########################################
if [[ "$(kubectl get pod config-broken -o jsonpath='{.status.phase}')" != "Running" ]]; then
  fail "config-broken pod is not running"
fi
pass "ConfigMap pod running"

########################################
# 7. PVC bound
########################################
PVC_PHASE=$(kubectl get pvc exam-pvc -o jsonpath='{.status.phase}')
if [[ "$PVC_PHASE" != "Bound" ]]; then
  fail "PVC is not Bound"
fi
pass "PersistentVolumeClaim bound successfully"

echo
echo "🎉 Cluster validation PASSED — great job!"
