#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="${CHART_DIR:-./server-chart}"
RELEASE="${RELEASE:-server}"
NS="${NS:-ch5-helm-test}"
TIMEOUT="${TIMEOUT:-120s}"
LOCAL_PORT="${LOCAL_PORT:-18080}"

pass() { printf "✅ %s\n" "$*"; }
fail() { printf "❌ %s\n" "$*" >&2; exit 1; }
warn() { printf "⚠️  %s\n" "$*" >&2; }

need() { command -v "$1" >/dev/null 2>&1 || fail "Missing dependency: $1"; }

need helm
need grep
need awk

[[ -d "$CHART_DIR" ]] || fail "Chart directory not found: $CHART_DIR"

echo "=== Challenge-5 Helm Chart Checks ==="
echo "Chart  : $CHART_DIR"
echo "Release: $RELEASE"
echo

# 1) helm lint
echo "[1/4] helm lint"
if helm lint "$CHART_DIR" >/tmp/helm_lint.out 2>&1; then
  pass "helm lint passed"
else
  cat /tmp/helm_lint.out >&2
  fail "helm lint failed"
fi

# 2) helm template + manifest checks
echo
echo "[2/4] helm template"
RENDERED="/tmp/helm_rendered.$$"
if helm template "$RELEASE" "$CHART_DIR" >"$RENDERED" 2>/tmp/helm_template.err; then
  pass "helm template rendered manifests"
else
  cat /tmp/helm_template.err >&2
  rm -f "$RENDERED"
  fail "helm template failed"
fi

grep -qE "^kind: Deployment" "$RENDERED" || fail "Rendered output missing a Deployment"
grep -qE "^kind: Service" "$RENDERED" || fail "Rendered output missing a Service"

if grep -qE "containerPort:\s*8080" "$RENDERED"; then
  pass "Deployment uses containerPort 8080"
else
  fail "Deployment does NOT include containerPort: 8080"
fi

# Robust Service extraction
SERVICE_BLOCK="$(awk '
  /^kind: Service$/ {insvc=1}
  insvc {print}
  insvc && /^kind: / && $0 !~ /^kind: Service$/ {insvc=0}
' "$RENDERED")"

echo "$SERVICE_BLOCK" | grep -qE "^[[:space:]]*port:[[:space:]]*8080([[:space:]]*)$" \
  && pass "Service exposes port 8080" \
  || fail "Service does NOT expose port 8080"

echo "$SERVICE_BLOCK" | grep -qE "^[[:space:]]*targetPort:[[:space:]]*(8080|http)([[:space:]]*)$" \
  && pass "Service has targetPort (8080 or named port 'http')" \
  || fail "Service missing targetPort 8080/'http'"

pass "Rendered manifests look valid (basic checks)"

# 3) helm install (optional)
echo
echo "[3/4] helm install (optional if cluster reachable)"
if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
  pass "Kubernetes cluster reachable"

  kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" >/dev/null

  helm upgrade --install "$RELEASE" "$CHART_DIR" -n "$NS" >/tmp/helm_install.out 2>&1 || {
    cat /tmp/helm_install.out >&2
    fail "helm install/upgrade failed"
  }
  pass "helm install/upgrade succeeded"

  DEPLOY="$(kubectl -n "$NS" get deploy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "$DEPLOY" ]] || fail "No Deployment found after install"
  kubectl -n "$NS" rollout status "deploy/$DEPLOY" --timeout="$TIMEOUT" >/dev/null \
    || fail "Deployment rollout did not complete in $TIMEOUT"
  pass "Deployment is ready: $DEPLOY"

  SVC="$(kubectl -n "$NS" get svc -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "$SVC" ]] || fail "No Service found after install"
  pass "Service found: $SVC"

  # 4) HTTP test
  echo
  echo "[4/4] HTTP check (port-forward + header verification)"
  need curl

  kubectl -n "$NS" port-forward "svc/$SVC" "${LOCAL_PORT}:8080" >/dev/null 2>&1 &
  PF_PID=$!

  cleanup() {
    kill "$PF_PID" >/dev/null 2>&1 || true
    echo
    echo "Cleaning up helm release..."
    helm uninstall "$RELEASE" -n "$NS" >/dev/null 2>&1 || true
    kubectl delete ns "$NS" >/dev/null 2>&1 || true
    echo "Done."
  }
  trap cleanup EXIT

  for _ in {1..30}; do
    if curl -s "http://127.0.0.1:${LOCAL_PORT}/" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done

  CODE="$(curl -sS -o /tmp/ch5_body.$$ -w '%{http_code}' -H 'Challenge: orcrist.org' "http://127.0.0.1:${LOCAL_PORT}/" || true)"
  BODY="$(cat /tmp/ch5_body.$$ 2>/dev/null || true)"
  rm -f /tmp/ch5_body.$$ >/dev/null 2>&1 || true

  echo "HTTP Status: $CODE"
  echo "Body       : $BODY"

  [[ "$CODE" == "200" ]] || fail "Expected HTTP 200 with correct header"
  echo "$BODY" | grep -q "Everything works!" || fail "Expected body to contain 'Everything works!'"
  pass "HTTP server responds correctly via Service routing"

  echo
  pass "ALL CHECKS PASSED"
  exit 0
else
  warn "No reachable Kubernetes cluster. Skipping helm install + HTTP test."
fi

echo
pass "Lint + Template checks passed. (Install/HTTP checks skipped)"