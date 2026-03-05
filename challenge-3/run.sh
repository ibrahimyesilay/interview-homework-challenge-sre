#!/usr/bin/env bash
set -euo pipefail

IMAGE="challenge3-http-server"
CONTAINER="challenge3-http-server-c"
PORT="${PORT:-8080}"
URL="http://localhost:${PORT}/"
HEADER="Challenge: orcrist.org"

cd "$(dirname "$0")"

detect_runtime() {
  if command -v docker >/dev/null 2>&1; then echo docker; return; fi
  if command -v podman >/dev/null 2>&1; then echo podman; return; fi
  echo none
}

install_podman() {
  read -rp "Docker/Podman not found. Install Podman now? [y/N]: " answer
  [[ "${answer,,}" =~ ^(y|yes|evet)$ ]] || { echo "Aborted."; exit 1; }

  OS="$(uname)"
  if [[ "$OS" == "Darwin" ]]; then
    command -v brew >/dev/null || { echo "Homebrew not found."; exit 1; }
    brew install podman >/dev/null
    podman machine init >/dev/null 2>&1 || true
    podman machine start >/dev/null
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      ubuntu|debian) sudo apt update -qq && sudo apt install -y podman >/dev/null ;;
      fedora) sudo dnf install -y podman >/dev/null ;;
      arch) sudo pacman -Sy --noconfirm podman >/dev/null ;;
      *) echo "Unsupported Linux distribution."; exit 1 ;;
    esac
  else
    echo "Unsupported OS."
    exit 1
  fi
}

RUNTIME="$(detect_runtime)"
if [[ "$RUNTIME" == "none" ]]; then
  install_podman
  RUNTIME="podman"
fi

# create Dockerfile if missing
if [[ ! -f Dockerfile ]]; then
cat > Dockerfile <<'EOF'
FROM python:3.13-slim
WORKDIR /app
COPY server.py /app/server.py
EXPOSE 8080
CMD ["python3", "server.py"]
EOF
fi

# build quietly
$RUNTIME build -t "$IMAGE" . >/dev/null

# remove old container
if $RUNTIME ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  $RUNTIME rm -f "$CONTAINER" >/dev/null 2>&1 || true
fi

# start container
$RUNTIME run -d --name "$CONTAINER" -p "${PORT}:8080" "$IMAGE" >/dev/null

cleanup() {
  echo
  echo "Cleaning up $RUNTIME container..."
  $RUNTIME rm -f "$CONTAINER" >/dev/null 2>&1 || true
  echo "Done."
}
trap cleanup EXIT

# quick readiness check
for _ in {1..15}; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' -H "$HEADER" "$URL" || true)"
  [[ "$code" == "200" ]] && break
  sleep 0.2
done

# final request
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