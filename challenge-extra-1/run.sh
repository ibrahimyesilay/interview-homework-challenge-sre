#!/usr/bin/env bash
set -euo pipefail

MANIFESTS_DIR="${MANIFESTS_DIR:-manifests}"
FORWARD_PORT="${FORWARD_PORT:-8080}"
PROFILE="${PROFILE:-minikube}"

# ---------------- Pretty output ----------------
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

ask_yesno() {
  local prompt="$1"
  local ans
  read -r -p "$prompt [y/N]: " ans || true
  ans="$(printf "%s" "${ans:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$ans" == "y" || "$ans" == "yes" || "$ans" == "evet" ]]
}

have(){ command -v "$1" >/dev/null 2>&1; }

# ---------------- OS detection ----------------
OS_RAW="$(uname -s 2>/dev/null || echo unknown)"
case "$OS_RAW" in
  Darwin) OS="mac" ;;
  Linux) OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  *) OS="unknown" ;;
esac

# ---------------- Install helpers ----------------
need_sudo() { [[ "$OS" == "linux" ]] && have sudo; }
sudo_run() { if need_sudo; then sudo "$@"; else "$@"; fi; }

install_linux_pkg() {
  local pkg="$1"
  if have apt-get; then
    sudo_run apt-get update -y >/dev/null
    sudo_run apt-get install -y "$pkg"
  elif have dnf; then
    sudo_run dnf install -y "$pkg"
  elif have yum; then
    sudo_run yum install -y "$pkg"
  elif have pacman; then
    sudo_run pacman -Sy --noconfirm "$pkg"
  elif have zypper; then
    sudo_run zypper --non-interactive install "$pkg"
  elif have apk; then
    sudo_run apk add --no-cache "$pkg"
  else
    die "No supported Linux package manager found to install: $pkg"
  fi
}

install_mac_brew() {
  local what="$1"
  have brew || die "Homebrew not found. Install brew first, then rerun."
  brew install "$what"
}

install_windows_winget() {
  local id="$1"
  have winget || return 1
  winget install --id "$id" -e --accept-source-agreements --accept-package-agreements
}
install_windows_choco() {
  local pkg="$1"
  have choco || return 1
  choco install -y "$pkg"
}

# ---------------- Ensure tools ----------------
kubectl_version_str() {
  (kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -n1 || true) | tr -d '\r'
}

ensure_kubectl() {
  if have kubectl; then
    ok "kubectl found: $(kubectl_version_str)"
    return
  fi
  step "kubectl not found"
  ask_yesno "Install kubectl automatically?" || die "kubectl is required."
  case "$OS" in
    mac) install_mac_brew kubectl ;;
    linux) install_linux_pkg kubectl || install_linux_pkg kubernetes-client ;;
    windows)
      install_windows_winget "Kubernetes.kubectl" || install_windows_choco "kubernetes-cli" || die "Install kubectl (need winget/choco)."
      ;;
    *) die "Unsupported OS for kubectl auto-install." ;;
  esac
  have kubectl || die "kubectl installation failed."
  ok "kubectl installed: $(kubectl_version_str)"
}

ensure_minikube() {
  if have minikube; then
    ok "minikube found: $(minikube version | head -n1 | tr -d '\r')"
    return
  fi
  step "minikube not found"
  ask_yesno "Install minikube automatically?" || die "minikube is required."
  case "$OS" in
    mac) install_mac_brew minikube ;;
    linux)
      if ! (install_linux_pkg minikube); then
        warn "minikube not available via repos; installing binary."
        curl -fsSL -o /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo_run install /tmp/minikube /usr/local/bin/minikube
      fi
      ;;
    windows)
      install_windows_winget "Kubernetes.minikube" || install_windows_choco "minikube" || die "Install minikube (need winget/choco)."
      ;;
    *) die "Unsupported OS for minikube auto-install." ;;
  esac
  have minikube || die "minikube installation failed."
  ok "minikube installed: $(minikube version | head -n1 | tr -d '\r')"
}

ensure_curl() {
  have curl && return
  step "curl not found"
  ask_yesno "Install curl automatically?" || die "curl is required for HTTP test."
  case "$OS" in
    mac) install_mac_brew curl ;;
    linux) install_linux_pkg curl ;;
    windows) install_windows_winget "curl.curl" || install_windows_choco "curl" || die "Install curl and rerun." ;;
  esac
  have curl || die "curl installation failed."
}

# ---------------- Docker/Podman checks ----------------
docker_ok() { have docker && docker info >/dev/null 2>&1; }
podman_ok() { have podman && podman info >/dev/null 2>&1; }

install_podman_if_needed() {
  if podman_ok; then
    ok "podman found: $(podman --version 2>/dev/null | tr -d '\r' || true)"
    return
  fi

  step "Podman not usable"
  ask_yesno "Install Podman now?" || die "A container runtime is required."
  case "$OS" in
    mac)
      install_mac_brew podman
      (podman machine init >/dev/null 2>&1 || true)
      (podman machine start >/dev/null 2>&1 || true)
      ;;
    linux) install_linux_pkg podman ;;
    windows)
      install_windows_winget "RedHat.Podman" || die "Install Podman Desktop manually on Windows, then rerun."
      ;;
    *) die "Unsupported OS for Podman install." ;;
  esac
  podman_ok || die "Podman installed but not usable (podman info failed)."
  ok "podman ready: $(podman --version 2>/dev/null | tr -d '\r' || true)"
}

# ---------------- QEMU ensure (macOS) ----------------
ensure_qemu_macos() {
  # qemu driver expects qemu-system-aarch64 on Apple Silicon
  if have qemu-system-aarch64; then
    ok "qemu found: $(qemu-system-aarch64 --version 2>/dev/null | head -n1 | tr -d '\r' || true)"
    return
  fi

  step "QEMU not found (required for minikube --driver=qemu on macOS)"
  ask_yesno "Install QEMU via Homebrew now?" || die "QEMU is required for qemu driver."
  install_mac_brew qemu

  have qemu-system-aarch64 || die "QEMU installation failed (qemu-system-aarch64 not in PATH)."
  ok "qemu installed: $(qemu-system-aarch64 --version 2>/dev/null | head -n1 | tr -d '\r' || true)"
}

# ---------------- Choose minikube driver ----------------
choose_driver() {
  if docker_ok; then
    echo "docker"
    return
  fi

  # macOS: avoid podman driver (unstable), prefer qemu
  if [[ "$OS" == "mac" ]]; then
    warn "Docker not usable. On macOS, minikube+podman driver is unstable; using qemu fallback."
    echo "qemu"
    return
  fi

  install_podman_if_needed
  echo "podman"
}

# ---------------- Start minikube with recovery ----------------
start_minikube_with_driver() {
  local driver="$1"

  # If qemu on mac, ensure qemu installed first
  if [[ "$OS" == "mac" && "$driver" == "qemu" ]]; then
    ensure_qemu_macos
  fi

  step "Starting Minikube (profile: $PROFILE, driver: $driver)"
  if minikube start -p "$PROFILE" --driver="$driver"; then
    ok "Minikube started (driver: $driver)"
    return 0
  fi

  warn "Minikube start failed (driver=$driver). Attempting recovery: minikube delete -p $PROFILE"
  minikube delete -p "$PROFILE" >/dev/null 2>&1 || true

  # Retry once after delete (handles driver mismatch / broken profile)
  if minikube start -p "$PROFILE" --driver="$driver"; then
    ok "Minikube started after recovery (driver: $driver)"
    return 0
  fi

  return 1
}

ensure_cluster() {
  step "Ensuring Minikube cluster is running"
  local driver
  driver="$(choose_driver)"
  ok "Selected Minikube driver: ${B}${driver}${R}"

  if minikube status -p "$PROFILE" >/dev/null 2>&1; then
    ok "Minikube already running"
  else
    start_minikube_with_driver "$driver" || die "Minikube failed to start with driver=$driver."
  fi

  ok "kubectl context: $(kubectl config current-context 2>/dev/null || echo unknown)"
}

# ---------------- Apply + info + port-forward ----------------
apply_manifests() {
  step "Applying manifests (safe order: namespaces -> wait for default SA -> rest)"

  [[ -d "$MANIFESTS_DIR" ]] || die "Manifests directory not found: $MANIFESTS_DIR"

  # 1) Apply namespaces first (expecting 00-namespaces.yml)
  if [[ -f "$MANIFESTS_DIR/00-namespaces.yml" ]]; then
    kubectl apply -f "$MANIFESTS_DIR/00-namespaces.yml" | sed 's/^/  /'
  else
    # fallback: apply anything that looks like namespaces
    warn "00-namespaces.yml not found; applying all manifests (may still work, but SA race can happen)."
    kubectl apply -f "$MANIFESTS_DIR" | sed 's/^/  /'
    ok "Manifests applied (no ordering possible)"
    return
  fi

  # 2) Wait until default ServiceAccount exists in created namespaces
  step "Waiting for default ServiceAccounts to be created"
  for ns in collector integration orcrist monitoring tools; do
    echo "  - ns/$ns: waiting for serviceaccount/default ..."
    for _ in {1..50}; do
      if kubectl get sa default -n "$ns" >/dev/null 2>&1; then
        echo "    ✔ found"
        break
      fi
      sleep 0.2
    done
    kubectl get sa default -n "$ns" >/dev/null 2>&1 || die "Timed out waiting for serviceaccount/default in namespace: $ns"
  done
  ok "Default ServiceAccounts are ready"

  # 3) Apply the rest (deployments/services/pods)
  # Apply in deterministic order if files exist
  if [[ -f "$MANIFESTS_DIR/01-deployments.yml" ]]; then
    kubectl apply -f "$MANIFESTS_DIR/01-deployments.yml" | sed 's/^/  /'
  fi
  if [[ -f "$MANIFESTS_DIR/02-pod.yml" ]]; then
    kubectl apply -f "$MANIFESTS_DIR/02-pod.yml" | sed 's/^/  /'
  fi

  ok "Manifests applied from $MANIFESTS_DIR"
}

info_commands() {
  step "Get all namespaces"
  kubectl get ns | sed 's/^/  /'

  step "Get all pods (all namespaces)"
  kubectl get pods -A -o wide | sed 's/^/  /'

  step "Get all resources (all namespaces)"
  kubectl get all -A | sed 's/^/  /'

  step "Get all services from namespace: orcrist"
  kubectl get svc -n orcrist | sed 's/^/  /'

  step "Get all deployments from namespace: tools"
  kubectl get deploy -n tools 2>&1 | sed 's/^/  /' || true

  step "Get image from nginx deployment in namespace: orcrist"
  local img
  img="$(kubectl get deploy nginx-deployment -n orcrist -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
  [[ -n "$img" ]] || die "Could not read image (is nginx-deployment applied?)"
  echo "  image: ${B}${img}${R}"
  ok "Image extracted"
}

port_forward_test() {
  step "Port-forward to access nginx (namespace: orcrist) + HTTP test"
  ensure_curl

  kubectl get svc -n orcrist nginx-service >/dev/null 2>&1 || die "Service orcrist/nginx-service not found."

  # Try to avoid port conflicts: if 8080 busy, pick a free port automatically
  local port="$FORWARD_PORT"
  if command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      warn "Local port $port is busy. Picking a random free port."
      port="$(python3 - <<'PY'
import socket
s=socket.socket()
s.bind(("127.0.0.1",0))
print(s.getsockname()[1])
s.close()
PY
)"
    fi
  fi

  kubectl port-forward -n orcrist svc/nginx-service "${port}:80" >/tmp/portfwd.log 2>&1 &
  PF_PID=$!

  cleanup() {
    kill "$PF_PID" >/dev/null 2>&1 || true
    wait "$PF_PID" >/dev/null 2>&1 || true
    echo
    ok "Cleanup: port-forward stopped. Done."
  }
  trap cleanup EXIT

  # Wait quickly
  for _ in {1..40}; do
    if curl -s "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
      break
    fi
    sleep 0.15
  done

  local code body
  code="$(curl -sS -o /tmp/nginx_body.$$ -w '%{http_code}' "http://127.0.0.1:${port}/" || true)"
  body="$(head -c 200 /tmp/nginx_body.$$ 2>/dev/null | tr '\n' ' ' || true)"
  rm -f /tmp/nginx_body.$$ >/dev/null 2>&1 || true

  echo "  URL : http://127.0.0.1:${port}/"
  echo "  HTTP: ${B}${code}${R}"

  if [[ "$code" == "200" ]] && echo "$body" | grep -qi "nginx"; then
    ok "Nginx reachable (HTTP 200, body contains 'nginx')"
  else
    warn "Unexpected response. Expected nginx (HTTP 200)."
    echo "  Body: ${body}"
    warn "If this persists, check port conflicts or /tmp/portfwd.log"
  fi
}

# ---------------- Main ----------------
cd "$(dirname "$0")"

step "Extra Challenge 1 – Kubernetes (Minikube Runner)"
ok "OS detected: ${B}${OS}${R}"
ok "Manifests dir: ${B}${MANIFESTS_DIR}${R}"
ok "Profile: ${B}${PROFILE}${R}"

ensure_kubectl
ensure_minikube
ensure_cluster
apply_manifests
info_commands
port_forward_test

echo
ok "All requested steps executed."