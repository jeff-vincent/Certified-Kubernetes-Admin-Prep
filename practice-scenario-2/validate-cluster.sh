#!/usr/bin/env bash
set -euo pipefail

fail() { echo "❌ FAIL: $1"; exit 1; }
pass() { echo "✅ PASS: $1"; }

########################################
# Nodes stable
########################################
kubectl get nodes --no-headers | awk '$2!="Ready"{exit 1}' \
  || fail "Node not Ready"
pass "Nodes Ready"

########################################
# Pod sandbox creation works
########################################
kubectl run net-test --image=busybox --restart=Never -- sleep 5 \
  || fail "Pod creation failed"
pass "Pod networking functional"

########################################
# DNS works
########################################
kubectl exec net-test -- nslookup kubernetes.default \
  || fail "DNS resolution broken"
pass "Cluster DNS healthy"

########################################
# RBAC works
########################################
kubectl auth can-i list pods \
  --as=system:serviceaccount:default:broken-app \
  >/dev/null || fail "RBAC incorrect"
pass "RBAC fixed"

########################################
# App running
########################################
kubectl get deploy crashy-app -o jsonpath='{.status.readyReplicas}' | grep -q 1 \
  || fail "Application not healthy"
pass "Application healthy"

########################################
# PVC bound
########################################
kubectl get pvc broken-pvc -o jsonpath='{.status.phase}' | grep -q Bound \
  || fail "PVC not bound"
pass "Storage fixed"

echo
echo "🎉 Scenario 02 validation PASSED"
