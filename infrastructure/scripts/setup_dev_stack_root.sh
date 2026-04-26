#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root (use: sudo bash $0)"
  exit 1
fi

TARGET_USER="${SUDO_USER:-${USER}}"
if ! getent passwd "${TARGET_USER}" >/dev/null; then
  echo "Cannot resolve target user: ${TARGET_USER}"
  exit 1
fi

# Mint is Ubuntu-based; Docker repo uses Ubuntu codename.
source /etc/os-release
UBUNTU_CODENAME="${UBUNTU_CODENAME:-noble}"
ARCH="$(dpkg --print-architecture)"

export DEBIAN_FRONTEND=noninteractive

echo "==> Installing base developer packages"
apt-get update
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  apt-transport-https \
  build-essential \
  pkg-config \
  make \
  gcc \
  g++ \
  git \
  wget \
  unzip \
  zip \
  jq \
  ripgrep \
  xz-utils \
  python3 \
  python3-venv \
  python3-pip \
  python3-dev \
  libssl-dev \
  libffi-dev

echo "==> Installing Docker repository"
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
echo "==> Installing Docker Engine + Compose"
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

if command -v systemctl >/dev/null 2>&1; then
  systemctl enable docker || true
  systemctl start docker || true
fi

if id -nG "${TARGET_USER}" | tr ' ' '\n' | grep -qx docker; then
  echo "User ${TARGET_USER} is already in docker group"
else
  usermod -aG docker "${TARGET_USER}"
  echo "Added ${TARGET_USER} to docker group"
fi

echo
echo "Root stack installation completed."
echo "Run this in a NEW terminal session (or after logout/login):"
echo "  docker --version && docker compose version && docker run --rm hello-world"
