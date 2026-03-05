#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-minikube}"
STACK="${STACK:-dev}"

echo "==> Destroying Extra Challenge 2 resources"

# ------------------------------------------------------------------
# Disable Pulumi prompts
# ------------------------------------------------------------------
export PULUMI_CONFIG_PASSPHRASE="local"
export PULUMI_SKIP_UPDATE_CHECK=true

# ------------------------------------------------------------------
# Dependency checks
# ------------------------------------------------------------------
require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1"
    exit 1
  }
}

require pulumi

# ------------------------------------------------------------------
# Activate venv if it exists
# ------------------------------------------------------------------
if [[ -f ".venv/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source ".venv/bin/activate"
elif [[ -f ".venv/Scripts/activate" ]]; then
  # shellcheck disable=SC1091
  source ".venv/Scripts/activate"
fi

# ------------------------------------------------------------------
# Local backend (no token / no cloud)
# ------------------------------------------------------------------
pulumi login --local >/dev/null 2>&1 || true

# ------------------------------------------------------------------
# Select stack if exists
# ------------------------------------------------------------------
if pulumi stack select "$STACK" >/dev/null 2>&1; then
  echo "==> Running pulumi destroy"
  pulumi destroy --yes
  echo "✔ Pulumi resources destroyed"
else
  echo "⚠ Pulumi stack '$STACK' not found, skipping destroy"
fi

# ------------------------------------------------------------------
# Remove stack (optional but useful)
# ------------------------------------------------------------------
if pulumi stack select "$STACK" >/dev/null 2>&1; then
  pulumi stack rm "$STACK" --yes >/dev/null 2>&1 || true
  echo "✔ Pulumi stack removed"
fi

# ------------------------------------------------------------------
# Delete minikube profile if available
# ------------------------------------------------------------------
if command -v minikube >/dev/null 2>&1; then
  echo "==> Deleting minikube profile: $PROFILE"
  minikube delete -p "$PROFILE" >/dev/null 2>&1 || true
  echo "✔ Minikube profile deleted"
fi

echo
echo "✔ Destroy completed."