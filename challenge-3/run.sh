#!/usr/bin/env bash
set -euo pipefail

IMAGE="challenge3-http-server"
TAG="latest"
FULL_IMAGE="${IMAGE}:${TAG}"
CONTAINER="challenge3-http-server-c"
PORT="${PORT:-8080}"
URL="http://127.0.0.1:${PORT}/"
HEADER="Challenge: orcrist.org"

cd "$(dirname "$0")"

# Runtime selection: docker preferred, else podman
if command -v docker >/dev/null 2>&1; then
  RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
  RUNTIME="podman"
else
  echo "ERROR: neither docker nor podman found."
  exit 1
fi

# macOS + podman needs podman machine
if [[ "$RUNTIME" == "podman" && "$(uname)" == "Darwin" ]]; then
  podman machine init >/dev/null 2>&1 || true
  podman machine start >/dev/null 2>&1 || true
fi

# Build image
$RUNTIME build -t "$FULL_IMAGE" . >/dev/null

# Remove old container if exists
if $RUNTIME ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  $RUNTIME rm -f "$CONTAINER" >/dev/null 2>&1 || true
fi

# Run container
$RUNTIME run -d --name "$CONTAINER" -p "${PORT}:8080" "$FULL_IMAGE" >/dev/null

cleanup() {
  echo
  echo "Cleaning up $RUNTIME container..."
  $RUNTIME rm -f "$CONTAINER" >/dev/null 2>&1 || true
  echo "Done."
}
trap cleanup EXIT

# Fast readiness check (expect 200 with correct header)
for _ in {1..20}; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' -H "$HEADER" "$URL" || true)"
  [[ "$code" == "200" ]] && break
  sleep 0.2
done

# Final request (pretty output)
HTTP_CODE="$(curl -sS -o /tmp/ch3_body.$$ -w '%{http_code}' -H "$HEADER" "$URL" || true)"
BODY="$(cat /tmp/ch3_body.$$ 2>/dev/null || true)"
rm -f /tmp/ch3_body.$$ >/dev/null 2>&1 || true

echo "=== Challenge-3 Result ==="
echo "Runtime : $RUNTIME"
echo "Status  : $HTTP_CODE"
echo "Body    : $BODY"

if [[ "$HTTP_CODE" == "200" && "$BODY" == "Everything works!" ]]; then
  echo "Verdict : PASS"
else
  echo "Verdict : FAIL"
fi