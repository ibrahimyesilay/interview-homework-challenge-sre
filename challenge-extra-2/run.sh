#!/usr/bin/env bash
set -euo pipefail

PROFILE="${PROFILE:-minikube}"
STACK="${STACK:-dev}"
PORT="${PORT:-8080}"

echo "==> Extra Challenge 2 – From scratch (bootstrap cluster + Pulumi provision + validate)"

# ------------------------------------------------------------------
# Disable Pulumi prompts (no passphrase prompt)
# ------------------------------------------------------------------
export PULUMI_CONFIG_PASSPHRASE="local"
export PULUMI_SKIP_UPDATE_CHECK=true

# ------------------------------------------------------------------
# Dependency checks
# ------------------------------------------------------------------
require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ Missing dependency: $1"
    exit 1
  }
}

require python3
require kubectl
require minikube
require pulumi
require curl

echo "✔ python3: $(python3 --version)"
echo "✔ kubectl: $(kubectl version --client --short 2>/dev/null || true)"
echo "✔ minikube: $(minikube version | head -n1)"
echo "✔ pulumi: $(pulumi version)"

# ------------------------------------------------------------------
# Start cluster
# ------------------------------------------------------------------
echo
echo "==> Ensuring Minikube cluster is running"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  echo "Starting minikube..."
  minikube start -p "$PROFILE"
else
  echo "✔ minikube already running"
fi

# ------------------------------------------------------------------
# Python virtual env
# ------------------------------------------------------------------
echo
echo "==> Preparing Python environment"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

python3 -m pip install --upgrade pip >/dev/null
python3 -m pip install -r requirements.txt >/dev/null

echo "✔ python dependencies installed"

# ------------------------------------------------------------------
# Pulumi local backend (NO cloud token)
# ------------------------------------------------------------------
echo
echo "==> Preparing Pulumi (local backend, non-interactive)"

pulumi login --local >/dev/null

pulumi stack select "$STACK" >/dev/null 2>&1 || pulumi stack init "$STACK" >/dev/null

# ------------------------------------------------------------------
# Deploy
# ------------------------------------------------------------------
echo
echo "==> Running Pulumi deployment"
pulumi up --yes --skip-preview
echo "✔ Pulumi deployment finished"

# ------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------
echo
echo "==> Namespaces"
kubectl get ns

echo
echo "==> Pods"
kubectl get pods -A

echo
echo "==> Services"
kubectl get svc -A

# ------------------------------------------------------------------
# Test nginx
# ------------------------------------------------------------------
echo
echo "==> Testing nginx via port-forward"

kubectl port-forward -n orcrist svc/nginx-service ${PORT}:80 >/dev/null 2>&1 &
PF_PID=$!

sleep 2

HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}")
echo "HTTP response: $HTTP"

kill "$PF_PID" >/dev/null 2>&1 || true

echo
echo "✔ Done."