#!/usr/bin/env bash
set -euo pipefail


fail(){ echo "❌ FAIL: $1"; exit 1; }
pass(){ echo "✅ PASS: $1"; }


kubectl get networkpolicy deny-all >/dev/null 2>&1 && fail "Blocking NetworkPolicy still exists"
pass "NetworkPolicy removed"


kubectl get statefulset broken-stateful -o jsonpath='{.status.readyReplicas}' | grep -q 1 \
|| fail "StatefulSet not ready"
pass "StatefulSet healthy"


echo "🎉 Scenario 05 validation PASSED"
