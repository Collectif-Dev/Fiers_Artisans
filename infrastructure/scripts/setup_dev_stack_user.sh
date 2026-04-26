#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user, not root."
  exit 1
fi

export PATH="$HOME/.local/bin:$PATH"

append_once() {
  local marker="$1"
  local content="$2"
  if ! grep -q "${marker}" "$HOME/.bashrc"; then
    printf "\n%s\n%s\n" "${marker}" "${content}" >> "$HOME/.bashrc"
  fi
}

echo "==> Installing nvm"
if [[ ! -d "$HOME/.nvm" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"

echo "==> Installing Node LTS"
nvm install --lts
nvm alias default 'lts/*'
nvm use default >/dev/null

if [[ -f "$HOME/.npmrc" ]]; then
  sed -i '/^prefix=/d' "$HOME/.npmrc"
fi

append_once "### DEV_STACK_LOCAL_BIN ###" "if [ -d \"\$HOME/.local/bin\" ]; then\n  export PATH=\"\$HOME/.local/bin:\$PATH\"\nfi"

echo "==> Enabling corepack and JS package managers"
corepack enable
corepack prepare pnpm@latest --activate
corepack prepare yarn@stable --activate

echo "==> Installing uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Installing Python versions (uv-managed)"
uv python install 3.11 3.12 3.13

echo "==> Installing Python CLI tools"
uv tool install pipx || true
uv tool install poetry || true
uv tool install ruff || true

echo
echo "User stack installation completed. Open a new terminal and validate:"
echo "  node -v && npm -v && pnpm -v && yarn -v"
echo "  uv --version && python3.12 --version && poetry --version && ruff --version"
