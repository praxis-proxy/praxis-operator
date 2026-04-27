#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

CLUSTER_NAME="${KIND_CLUSTER_NAME:-praxis-conformance}"
GWAPI_VERSION="${GWAPI_VERSION:-v1.5.1}"
GWAPI_CONFORMANCE_TAG="${GWAPI_CONFORMANCE_TAG:-monthly-2026.05}"
GWAPI_DIR="/tmp/gateway-api"
GATEWAY_CLASS="${GATEWAY_CLASS:-praxis}"

# ---------------------------------------------------------------------------
# Isolated KUBECONFIG
# ---------------------------------------------------------------------------

KUBECONFIG_FILE="/tmp/kind-${CLUSTER_NAME}.kubeconfig"
kind get kubeconfig --name "${CLUSTER_NAME}" > "${KUBECONFIG_FILE}"
export KUBECONFIG="${KUBECONFIG_FILE}"
trap "rm -f ${KUBECONFIG_FILE}" EXIT

# ---------------------------------------------------------------------------
# Gateway API Source
# ---------------------------------------------------------------------------

if [ ! -d "${GWAPI_DIR}" ]; then
    echo "==> Cloning gateway-api ${GWAPI_CONFORMANCE_TAG}..."
    git clone --depth 1 --branch "${GWAPI_CONFORMANCE_TAG}" \
        https://github.com/kubernetes-sigs/gateway-api.git \
        "${GWAPI_DIR}"
else
    echo "==> Using cached gateway-api at ${GWAPI_DIR}"
fi

# ---------------------------------------------------------------------------
# Run Tests
# ---------------------------------------------------------------------------

echo "==> Running conformance tests (context: kind-${CLUSTER_NAME})..."
cd "${GWAPI_DIR}"
go test ./conformance -run TestConformance \
    -timeout 60m -v \
    -args \
    --gateway-class="${GATEWAY_CLASS}" \
    --conformance-profiles=GATEWAY-HTTP \
    --timeout-config-overrides="MaxTimeToConsistency:120;NamespacesMustBeReady:600" \
    --allow-crds-mismatch \
    --debug \
    --report-output=/tmp/conformance-report.yaml \
    --organization=praxis-proxy \
    --project=praxis-operator \
    --version=v0.1.0 \
    --url=https://github.com/praxis-proxy/praxis-operator \
    --contact=@shaneutt

echo "==> Conformance report: /tmp/conformance-report.yaml"
