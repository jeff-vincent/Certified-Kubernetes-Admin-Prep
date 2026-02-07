#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

pass() {
  echo "✅ PASS: $1"
  PASS=$((PASS+1))
}

fail() {
  echo "❌ FAIL: $1"
  FAIL=$((FAIL+1))
}

echo "🔎 Validating Practice Exam 3..."
echo

########################################
# Discover nodes
########################################
WORKER_NODE=$(kubectl get nodes --no-headers | awk '$3 !~ /control-plane/ {print $1}')
WORKER_IP=$(kubectl get node "$WORKER_NODE" \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
SSH_OPTS="-o StrictHostKeyChecking=no"

########################################
# Task 1 — etcd Backup (7%)
########################################
if [[ -f /opt/etcd-backup.db ]] && [[ -s /opt/etcd-backup.db ]]; then
  # Verify it's a valid snapshot
  if ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db >/dev/null 2>&1; then
    pass "Task 1  (7%)  — etcd snapshot saved to /opt/etcd-backup.db"
  else
    fail "Task 1  (7%)  — /opt/etcd-backup.db exists but is not a valid etcd snapshot"
  fi
else
  fail "Task 1  (7%)  — /opt/etcd-backup.db not found or empty"
fi

########################################
# Task 2 — etcd Restore (7%)
########################################
if [[ -d /var/lib/etcd-restored/member ]]; then
  pass "Task 2  (7%)  — etcd restored to /var/lib/etcd-restored"
else
  fail "Task 2  (7%)  — /var/lib/etcd-restored/member directory not found"
fi

########################################
# Task 3 — Fix Worker Node (8%)
########################################
NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2 != "Ready" {print $1}')
if [[ -z "$NOT_READY" ]]; then
  pass "Task 3  (8%)  — All nodes are Ready"
else
  fail "Task 3  (8%)  — Nodes not Ready: $NOT_READY"
fi

########################################
# Task 4 — Drain & Uncordon (5%)
########################################
UNSCHED=$(kubectl get node "$WORKER_NODE" -o jsonpath='{.spec.unschedulable}' 2>/dev/null || echo "")
MAINT_FILE="no"
if [[ -n "$WORKER_IP" ]]; then
  MAINT_FILE=$(ssh $SSH_OPTS root@"$WORKER_IP" "test -f /opt/maintenance-complete && echo yes || echo no" 2>/dev/null || echo "no")
fi

if [[ "$UNSCHED" != "true" ]] && [[ "$MAINT_FILE" == "yes" ]]; then
  pass "Task 4  (5%)  — Node drained, maintenance file created, node uncordoned"
else
  REASON=""
  [[ "$UNSCHED" == "true" ]] && REASON="node still cordoned; "
  [[ "$MAINT_FILE" != "yes" ]] && REASON="${REASON}/opt/maintenance-complete not found on worker"
  fail "Task 4  (5%)  — ${REASON}"
fi

########################################
# Task 5 — DaemonSet (5%)
########################################
DS_NAME=$(kubectl get daemonset log-collector -n monitoring -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
if [[ "$DS_NAME" == "log-collector" ]]; then
  DS_DESIRED=$(kubectl get daemonset log-collector -n monitoring -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
  DS_READY=$(kubectl get daemonset log-collector -n monitoring -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
  if [[ "$DS_DESIRED" -ge 2 ]] && [[ "$DS_READY" -ge 2 ]]; then
    pass "Task 5  (5%)  — DaemonSet log-collector running on all nodes ($DS_READY/$DS_DESIRED)"
  else
    fail "Task 5  (5%)  — DaemonSet exists but not on all nodes (ready: $DS_READY, desired: $DS_DESIRED — check tolerations)"
  fi
else
  fail "Task 5  (5%)  — DaemonSet log-collector not found in monitoring namespace"
fi

########################################
# Task 6 — Multi-container Pod (7%)
########################################
POD_PHASE=$(kubectl get pod multi-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
CONTAINER_COUNT=$(kubectl get pod multi-pod -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | wc -w || echo "0")
INIT_NAME=$(kubectl get pod multi-pod -o jsonpath='{.spec.initContainers[0].name}' 2>/dev/null || echo "")
if [[ "$POD_PHASE" == "Running" ]] && [[ "$CONTAINER_COUNT" -ge 2 ]] && [[ "$INIT_NAME" == "init-data" ]]; then
  pass "Task 6  (7%)  — Multi-container pod running (init: $INIT_NAME, containers: $CONTAINER_COUNT)"
else
  fail "Task 6  (7%)  — Multi-container pod not correctly configured (phase: $POD_PHASE, containers: $CONTAINER_COUNT, init: $INIT_NAME)"
fi

########################################
# Task 7 — Rolling Update & Rollback (5%)
########################################
ROLLOUT_IMAGE=$(kubectl get deployment rollout-app -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
HAS_HISTORY=$(kubectl rollout history deployment rollout-app 2>/dev/null | grep -cE "^[0-9]" || echo "0")
if [[ "$ROLLOUT_IMAGE" == "nginx:1.24.0" ]] && [[ "$HAS_HISTORY" -ge 2 ]]; then
  pass "Task 7  (5%)  — Deployment rolled back to nginx:1.24.0 with revision history"
else
  fail "Task 7  (5%)  — Rollback not complete (image: $ROLLOUT_IMAGE, revisions: $HAS_HISTORY)"
fi

########################################
# Task 8 — Scale + Resource Limits (5%)
########################################
REPLICAS=$(kubectl get deployment scale-app -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
CPU_REQ=$(kubectl get deployment scale-app -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
MEM_LIM=$(kubectl get deployment scale-app -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
if [[ "$REPLICAS" == "4" ]] && [[ -n "$CPU_REQ" ]] && [[ -n "$MEM_LIM" ]]; then
  pass "Task 8  (5%)  — Deployment scaled to 4 with resources (cpu req: $CPU_REQ, mem lim: $MEM_LIM)"
else
  fail "Task 8  (5%)  — Scale/resources not set (replicas: $REPLICAS, cpu_req: $CPU_REQ, mem_lim: $MEM_LIM)"
fi

########################################
# Task 9 — NodePort Service (5%)
########################################
SVC_TYPE=$(kubectl get service backend-svc -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
NODE_PORT=$(kubectl get service backend-svc -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
SVC_SELECTOR=$(kubectl get service backend-svc -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
if [[ "$SVC_TYPE" == "NodePort" ]] && [[ "$NODE_PORT" == "30080" ]] && [[ "$SVC_SELECTOR" == "backend" ]]; then
  pass "Task 9  (5%)  — NodePort service backend-svc on port 30080"
else
  fail "Task 9  (5%)  — Service not correct (type: $SVC_TYPE, nodePort: $NODE_PORT, selector: $SVC_SELECTOR)"
fi

########################################
# Task 10 — Node Affinity (5%)
########################################
AFFINITY_PHASE=$(kubectl get pod affinity-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
AFFINITY_NODE=$(kubectl get pod affinity-pod -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "")
# Check that the pod spec has node affinity configured
AFFINITY_KEY=$(kubectl get pod affinity-pod -o jsonpath='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key}' 2>/dev/null || echo "")
if [[ "$AFFINITY_PHASE" == "Running" ]] && [[ "$AFFINITY_KEY" == "disk" ]]; then
  pass "Task 10 (5%)  — Pod affinity-pod running on $AFFINITY_NODE with node affinity (key: $AFFINITY_KEY)"
else
  fail "Task 10 (5%)  — affinity-pod not correct (phase: $AFFINITY_PHASE, affinity key: $AFFINITY_KEY)"
fi

########################################
# Task 11 — Container Logs (5%)
########################################
if [[ -f /opt/error-logs.txt ]] && [[ -s /opt/error-logs.txt ]]; then
  HAS_ERROR=$(grep -c "ERROR" /opt/error-logs.txt || echo "0")
  HAS_INFO=$(grep -c "INFO" /opt/error-logs.txt || echo "0")
  if [[ "$HAS_ERROR" -gt 0 ]] && [[ "$HAS_INFO" -eq 0 ]]; then
    pass "Task 11 (5%)  — Error logs saved ($HAS_ERROR ERROR lines, no INFO lines)"
  else
    fail "Task 11 (5%)  — Log file has wrong content (ERROR lines: $HAS_ERROR, INFO lines: $HAS_INFO)"
  fi
else
  fail "Task 11 (5%)  — /opt/error-logs.txt not found or empty"
fi

########################################
# Task 12 — RBAC (8%)
########################################
SA_EXISTS=$(kubectl get sa deploy-bot -n dev-team -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
CR_EXISTS=$(kubectl get clusterrole pod-reader -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
CAN_LIST=$(kubectl auth can-i list pods --as=system:serviceaccount:dev-team:deploy-bot 2>/dev/null || echo "no")
CAN_LIST_SYSTEM=$(kubectl auth can-i list pods --as=system:serviceaccount:dev-team:deploy-bot -n kube-system 2>/dev/null || echo "no")
if [[ "$SA_EXISTS" == "deploy-bot" ]] && [[ "$CR_EXISTS" == "pod-reader" ]] && [[ "$CAN_LIST" == "yes" ]] && [[ "$CAN_LIST_SYSTEM" == "yes" ]]; then
  pass "Task 12 (8%)  — ServiceAccount deploy-bot with ClusterRole pod-reader working"
else
  fail "Task 12 (8%)  — RBAC not complete (SA: $SA_EXISTS, CR: $CR_EXISTS, can-list: $CAN_LIST, cross-ns: $CAN_LIST_SYSTEM)"
fi

########################################
# Task 13 — NetworkPolicy (8%)
########################################
NP_NAME=$(kubectl get networkpolicy allow-backend-only -n web-app -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
NP_POD_SEL=$(kubectl get networkpolicy allow-backend-only -n web-app -o jsonpath='{.spec.podSelector.matchLabels.app}' 2>/dev/null || echo "")
NP_NS_SEL=$(kubectl get networkpolicy allow-backend-only -n web-app -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels.purpose}' 2>/dev/null || echo "")
if [[ "$NP_NAME" == "allow-backend-only" ]] && [[ "$NP_POD_SEL" == "web" ]] && [[ "$NP_NS_SEL" == "backend" ]]; then
  pass "Task 13 (8%)  — NetworkPolicy allow-backend-only correctly configured"
else
  fail "Task 13 (8%)  — NetworkPolicy not correct (name: $NP_NAME, podSelector: $NP_POD_SEL, nsSelector: $NP_NS_SEL)"
fi

########################################
# Task 14 — PV + PVC + Pod (8%)
########################################
PV_STATUS=$(kubectl get pv exam-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
PVC_STATUS=$(kubectl get pvc exam-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
STOR_POD=$(kubectl get pod storage-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
STOR_VOL=$(kubectl get pod storage-pod -o jsonpath='{.spec.volumes[?(@.persistentVolumeClaim)].persistentVolumeClaim.claimName}' 2>/dev/null || echo "")
if [[ "$PV_STATUS" == "Bound" ]] && [[ "$PVC_STATUS" == "Bound" ]] && [[ "$STOR_POD" == "Running" ]] && [[ "$STOR_VOL" == "exam-pvc" ]]; then
  pass "Task 14 (8%)  — PV, PVC, and Pod correctly configured and bound"
else
  fail "Task 14 (8%)  — Storage not correct (PV: $PV_STATUS, PVC: $PVC_STATUS, Pod: $STOR_POD, claimName: $STOR_VOL)"
fi

########################################
# Task 15 — JSONPath Output (7%)
########################################
T15_SCORE=0

if [[ -f /opt/node-ips.txt ]] && [[ -s /opt/node-ips.txt ]]; then
  # Verify IPs look reasonable (at least 2 lines with IP-like content)
  IP_COUNT=$(grep -cE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /opt/node-ips.txt || echo "0")
  if [[ "$IP_COUNT" -ge 2 ]]; then
    T15_SCORE=$((T15_SCORE+1))
    echo "  ✓ Task 15a — Node IPs saved ($IP_COUNT IPs found)"
  else
    echo "  ✗ Task 15a — /opt/node-ips.txt has fewer than 2 IPs"
  fi
else
  echo "  ✗ Task 15a — /opt/node-ips.txt not found or empty"
fi

if [[ -f /opt/sorted-pods.txt ]] && [[ -s /opt/sorted-pods.txt ]]; then
  POD_COUNT=$(wc -l < /opt/sorted-pods.txt | tr -d ' ')
  EXPECTED=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$POD_COUNT" -ge "$EXPECTED" ]]; then
    T15_SCORE=$((T15_SCORE+1))
    echo "  ✓ Task 15b — Sorted pods saved ($POD_COUNT pods listed)"
  else
    echo "  ✗ Task 15b — /opt/sorted-pods.txt has $POD_COUNT lines, expected $EXPECTED"
  fi
else
  echo "  ✗ Task 15b — /opt/sorted-pods.txt not found or empty"
fi

if [[ "$T15_SCORE" -eq 2 ]]; then
  pass "Task 15 (7%)  — JSONPath queries completed"
else
  fail "Task 15 (7%)  — JSONPath queries incomplete ($T15_SCORE/2 sub-tasks)"
fi

########################################
# Summary
########################################
TOTAL=15
SCORE=0

# Calculate weighted score
echo
echo "========================================="
echo "         EXAM RESULTS"
echo "========================================="
echo
echo "  Tasks passed:  $PASS / $TOTAL"
echo "  Tasks failed:  $FAIL / $TOTAL"
echo

if [[ $FAIL -eq 0 ]]; then
  echo "🎉 ALL VALIDATIONS PASSED — Excellent work!"
  echo "   You've covered key CKA gaps: etcd ops,"
  echo "   node maintenance, DaemonSets, multi-container"
  echo "   pods, rollouts, scaling, services, affinity,"
  echo "   logging, RBAC, NetworkPolicy, storage, and"
  echo "   JSONPath queries."
elif [[ $PASS -ge 12 ]]; then
  echo "🔥 Strong performance! Review the failed tasks"
  echo "   and try again."
elif [[ $PASS -ge 8 ]]; then
  echo "📈 Good progress. Keep practicing the areas"
  echo "   that didn't pass."
else
  echo "⚠️  Several tasks need attention. Focus on"
  echo "   troubleshooting first, then workload tasks."
fi

echo
echo "========================================="
