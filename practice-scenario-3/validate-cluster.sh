#!/usr/bin/env bash
set -euo pipefail


fail(){ echo "❌ FAIL: $1"; exit 1; }
pass(){ echo "✅ PASS: $1"; }


kubectl get --raw=/healthz >/dev/null 2>&1 \
|| fail "API server unhealthy"
pass "API server healthy"


kubectl get pods -n kube-system | grep kube-controller-manager | grep Running \
|| fail "Controller manager unstable"
pass "Controller manager stable"


echo "🎉 Scenario 03 validation PASSED"