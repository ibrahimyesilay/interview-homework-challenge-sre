#!/usr/bin/env bash
set -euo pipefail

CHART_PATH="${CHART_PATH:-../challenge-5/server-chart}"

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

step "Extra Challenge 3 – Helm chart tests (helm-unittest)"
echo "Chart: ${CHART_PATH}"

have helm || die "helm not found. Install Helm and retry."

if [[ ! -d "$CHART_PATH" ]]; then
  die "Chart not found at: $CHART_PATH (set CHART_PATH env var if your path differs)"
fi
ok "helm: $(helm version --short 2>/dev/null || true)"

# Ensure tests are present in chart (copy-in)
step "Ensuring tests are present in chart"
mkdir -p "${CHART_PATH}/tests"
cp -f ./tests/*.yaml "${CHART_PATH}/tests/"
ok "tests copied into ${CHART_PATH}/tests"

# helm-unittest plugin
step "Checking helm-unittest plugin"
if ! helm plugin list 2>/dev/null | awk '{print $1}' | grep -qx 'unittest'; then
  warn "helm-unittest plugin not installed."
  read -rp "Install helm-unittest plugin now? [y/N]: " ans
  if [[ ! "$ans" =~ ^([yY]|yes|YES|Yes|evet|EVET)$ ]]; then
    die "Cannot continue without helm-unittest plugin."
  fi

  # Some Helm builds enforce plugin signature verification; the upstream repo does not provide it.
  # --verify=false skips verification safely for this interview/homework use-case.
  if helm plugin install --help 2>/dev/null | grep -q -- '--verify'; then
    helm plugin install --verify=false https://github.com/helm-unittest/helm-unittest >/dev/null
  else
    # Older Helm versions don't support --verify flag.
    helm plugin install https://github.com/helm-unittest/helm-unittest >/dev/null
  fi
  ok "helm-unittest installed"
else
  ok "helm-unittest already installed"
fi

# Run tests
step "Running helm unittest"
helm unittest "$CHART_PATH"

echo
ok "All helm-unittest suites passed. Done."
