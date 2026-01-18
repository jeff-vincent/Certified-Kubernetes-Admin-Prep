#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "❌ FAIL: $1"
  exit 1
}

pass() {
  echo "✅ PASS: $1"
}

echo "🔎 Validating Scenario 2..."
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
# 2. kube-proxy running
########################################
KPOD=$(kubectl -n kube-system get pods -l k8s-app=kube-proxy --no-headers | awk '$3!="Running"{print $1}' || true)
if [[ -n "$KPOD" ]]; then
  fail "kube-proxy is not running on all nodes"
fi
pass "kube-proxy healthy"

########################################
# 3. Scheduler healthy
########################################
SCHED=$(kubectl -n kube-system get pods | grep kube-scheduler | grep -v Running || true)
if [[ -n "$SCHED" ]]; then
  fail "kube-scheduler is unhealthy"
fi
pass "Scheduler running"

########################################
# 4. RBAC fixed
########################################
kubectl auth can-i list nodes \
  --as=system:serviceaccount:monitoring:ops-audit \
  >/dev/null 2>&1 \
  || fail "RBAC still blocking node list access"
pass "RBAC permissions corrected"

########################################
# 5. StatefulSet healthy
########################################
READY=$(kubectl get sts db -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [[ "$READY" != "1" ]]; then
  fail "StatefulSet db is not healthy"
fi
pass "StatefulSet db healthy"

########################################
# 6. Secret pod running
########################################
if [[ "$(kubectl get pod secret-consumer -o jsonpath='{.status.phase}')" != "Running" ]]; then
  fail "secret-consumer pod is not running"
fi
pass "Secret pod running"

########################################
# 7. Ingress routes traffic
########################################
kubectl run tmp-check --image=busybox --restart=Never --rm -it -- \
  sh -c "wget -qO- http://web.example.local || exit 1" >/dev/null 2>&1 \
  || fail "Ingress is not routing correctly"
pass "Ingress routing working"

########################################
# 8. PVC bound
########################################
if [[ "$(kubectl get pvc app-data -o jsonpath='{.status.phase}')" != "Bound" ]]; then
  fail "PVC app-data is not Bound"
fi
pass "PersistentVolumeClaim bound"

echo
echo "🎉 Scenario 2 PASSED — excellent troubleshooting!"
