#!/usr/bin/env bash
set -euo pipefail


fail(){ echo "❌ FAIL: $1"; exit 1; }
pass(){ echo "✅ PASS: $1"; }


kubectl get pod pending-pod -o jsonpath='{.status.phase}' | grep -q Running \
|| fail "Pod not running"
pass "Pod scheduled and running"


kubectl describe node | grep -q Taints && fail "Node still tainted"
pass "No blocking taints present"


echo "🎉 Scenario 04 validation PASSED"