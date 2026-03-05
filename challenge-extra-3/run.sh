#!/usr/bin/env bash
set -euo pipefail

CHART_PATH="${CHART_PATH:-../challenge-5/server-chart}"
TEST_DIR="${CHART_PATH}/tests"

# -------- pretty output --------
if command -v tput >/dev/null 2>&1; then
  B="$(tput bold)"; R="$(tput sgr0)"
  G="$(tput setaf 2)"; Y="$(tput setaf 3)"; Z="$(tput setaf 4)"; E="$(tput setaf 1)"
else
  B=""; R=""; G=""; Y=""; Z=""; E=""
fi

step(){ echo; echo "${B}${Z}==>${R} ${B}$*${R}"; }
ok(){ echo "${G}✔${R} $*"; }
warn(){ echo "${Y}⚠${R} $*" >&2; }
die(){ echo "${E}✖${R} $*" >&2; exit 1; }

have(){ command -v "$1" >/dev/null 2>&1; }

cd "$(dirname "$0")"

cleanup() {
  step "Cleaning temporary test files"
  rm -f "${TEST_DIR}/deployment_test.yaml" || true
  rm -f "${TEST_DIR}/service_test.yaml" || true
  ok "temporary tests removed"
}

trap cleanup EXIT

step "Extra Challenge 3 – Helm chart tests (helm-unittest)"
echo "Chart: ${CHART_PATH}"

have helm || die "helm not found. Install Helm and retry."

if [[ ! -d "$CHART_PATH" ]]; then
  die "Chart not found at: $CHART_PATH"
fi

ok "helm: $(helm version --short 2>/dev/null || true)"

# Copy tests
step "Copying test suites to chart"
mkdir -p "${TEST_DIR}"
cp -f ./tests/*.yaml "${TEST_DIR}/"
ok "tests copied"

# Ensure plugin
step "Checking helm-unittest plugin"

if ! helm plugin list 2>/dev/null | awk '{print $1}' | grep -qx 'unittest'; then
  warn "helm-unittest plugin not installed."

  helm plugin install --verify=false https://github.com/helm-unittest/helm-unittest >/dev/null

  ok "helm-unittest installed"
else
  ok "helm-unittest already installed"
fi

# Run tests
step "Running helm unittest"

helm unittest "$CHART_PATH"

echo
ok "All helm-unittest suites passed. Done."