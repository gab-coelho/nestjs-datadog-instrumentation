#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: ./scripts/install.sh

Installs the Ubuntu host tools required by this lab:
  - Docker Engine and Docker Compose plugin
  - kubectl
  - kind
  - Helm
  - k6

The script configures upstream repositories/binaries for the latest stable
versions available at install time. It requires sudo privileges plus curl and
gpg on the host so APT can be updated only once after repositories are ready.
EOF
}

log() {
  echo "==> $*"
}

tmp_files=()
cleanup_tmp_files() {
  if [ "${#tmp_files[@]}" -gt 0 ]; then
    rm -f "${tmp_files[@]}"
  fi
}
trap cleanup_tmp_files EXIT

make_tmp() {
  tmp="$(mktemp)"
  tmp_files+=("$tmp")
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

sudo_cmd() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

target_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    echo "$SUDO_USER"
  elif [ "$(id -u)" -ne 0 ]; then
    echo "$USER"
  fi
}

assert_ubuntu() {
  if [ ! -r /etc/os-release ]; then
    echo "unable to detect OS: /etc/os-release is missing" >&2
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  if [ "${ID:-}" != "ubuntu" ]; then
    echo "this installer is tailored for Ubuntu; detected '${PRETTY_NAME:-unknown}'" >&2
    exit 1
  fi

  ubuntu_codename="${VERSION_CODENAME:-}"
  if [ -z "$ubuntu_codename" ]; then
    need lsb_release
    ubuntu_codename="$(lsb_release -cs)"
  fi
}

apt_install_lab_packages() {
  log "Installing APT-managed lab tools"
  sudo_cmd apt-get update
  sudo_cmd apt-get install -y \
    ca-certificates \
    containerd.io \
    docker-buildx-plugin \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin \
    k6
}

remove_conflicting_docker_packages() {
  log "Removing conflicting Docker packages if present"
  packages="$(dpkg --get-selections \
    docker.io \
    docker-compose \
    docker-compose-v2 \
    docker-doc \
    podman-docker \
    containerd \
    runc 2>/dev/null | cut -f1 || true)"

  if [ -n "$packages" ]; then
    # shellcheck disable=SC2086
    sudo_cmd apt-get remove -y $packages
  fi
}

install_docker() {
  remove_conflicting_docker_packages

  log "Configuring Docker APT repository"
  sudo_cmd install -m 0755 -d /etc/apt/keyrings
  sudo_cmd rm -f /etc/apt/keyrings/docker.asc
  sudo_cmd curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo_cmd chmod a+r /etc/apt/keyrings/docker.asc

  sudo_cmd tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${ubuntu_codename}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

configure_docker_after_install() {
  if command -v systemctl >/dev/null 2>&1; then
    sudo_cmd systemctl enable --now docker
  fi

  docker_user="$(target_user)"
  if [ -n "$docker_user" ]; then
    sudo_cmd usermod -aG docker "$docker_user"
  fi
}

install_kubectl() {
  log "Installing latest stable kubectl"
  kubectl_version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  case "$(uname -m)" in
    x86_64) kubectl_arch="amd64" ;;
    aarch64 | arm64) kubectl_arch="arm64" ;;
    *)
      echo "unsupported architecture for kubectl: $(uname -m)" >&2
      exit 1
      ;;
  esac

  make_tmp
  curl -fsSL -o "$tmp" "https://dl.k8s.io/release/${kubectl_version}/bin/linux/${kubectl_arch}/kubectl"
  sudo_cmd install -m 0755 "$tmp" /usr/local/bin/kubectl
}

install_kind() {
  log "Installing latest stable kind"
  case "$(uname -m)" in
    x86_64) kind_arch="amd64" ;;
    aarch64 | arm64) kind_arch="arm64" ;;
    *)
      echo "unsupported architecture for kind: $(uname -m)" >&2
      exit 1
      ;;
  esac

  kind_version="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest |
    sed -n 's/.*"tag_name": "\(v[^"]*\)".*/\1/p' |
    head -n 1)"
  if [ -z "$kind_version" ]; then
    echo "unable to determine latest kind release" >&2
    exit 1
  fi

  make_tmp
  curl -fsSL -o "$tmp" "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-${kind_arch}"
  sudo_cmd install -m 0755 "$tmp" /usr/local/bin/kind
}

install_helm() {
  log "Installing latest stable Helm"
  make_tmp
  curl -fsSL -o "$tmp" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
  chmod 700 "$tmp"
  sudo_cmd "$tmp"
}

install_k6() {
  log "Configuring k6 APT repository"
  sudo_cmd rm -f /usr/share/keyrings/k6-archive-keyring.gpg
  curl -fsSL https://dl.k6.io/key.gpg |
    sudo_cmd gpg --dearmor -o /usr/share/keyrings/k6-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" |
    sudo_cmd tee /etc/apt/sources.list.d/k6.list >/dev/null
}

print_versions() {
  log "Installed versions"
  docker --version || true
  docker compose version || true
  kubectl version --client=true || true
  kind version || true
  helm version --short || true
  k6 version || true

  docker_user="$(target_user)"
  if [ -n "$docker_user" ]; then
    cat <<EOF

Docker group membership was updated for user '$docker_user'.
Open a new shell, or run 'newgrp docker', before running Docker without sudo.
EOF
  fi
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage
    exit 1
    ;;
esac

need apt-get
if [ "$(id -u)" -ne 0 ]; then
  need sudo
fi

assert_ubuntu
need curl
need gpg
install_docker
install_k6
apt_install_lab_packages
configure_docker_after_install
install_kubectl
install_kind
install_helm
print_versions
