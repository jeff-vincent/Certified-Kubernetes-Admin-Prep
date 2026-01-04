#!/usr/bin/env bash
set -euo pipefail


echo "🚨 Breaking cluster — Scenario 03 (Control Plane & Certs)"


APISERVER_MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
CONTROLLER_MANIFEST="/etc/kubernetes/manifests/kube-controller-manager.yaml"


# Break API server cert reference
if ! grep -q bad-apiserver.crt "$APISERVER_MANIFEST"; then
sed -i.bak 's|--tls-cert-file=.*|--tls-cert-file=/etc/kubernetes/pki/bad-apiserver.crt|' "$APISERVER_MANIFEST"
fi


# Break controller-manager kubeconfig
if ! grep -q nonexistent "$CONTROLLER_MANIFEST"; then
sed -i.bak 's|--kubeconfig=.*|--kubeconfig=/etc/kubernetes/nonexistent.conf|' "$CONTROLLER_MANIFEST"
fi


echo "✅ Scenario 03 broken"