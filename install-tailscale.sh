#!/usr/bin/env bash
set -euo pipefail

# Linux gets the daemon and CLI from the official stable installer. macOS
# keeps an existing App Store/manual installation, or installs the GUI cask
# only when neither the CLI nor app bundle is present.
case "$(uname -s)" in
  Darwin)
    system_app="${TAILSCALE_APP_PATH:-/Applications/Tailscale.app}"
    user_app="${TAILSCALE_USER_APP_PATH:-$HOME/Applications/Tailscale.app}"

    if command -v tailscale >/dev/null 2>&1 \
      || [ -d "$system_app" ] \
      || [ -d "$user_app" ]; then
      echo "==> tailscale already installed, skipping setup"
      exit 0
    fi

    if ! command -v brew >/dev/null 2>&1; then
      echo "WARNING: Homebrew is unavailable; cannot install Tailscale, continuing" >&2
      exit 0
    fi

    echo "==> Installing tailscale-app (Homebrew cask)"
    brew install --cask tailscale-app \
      || echo "WARNING: tailscale-app install failed, continuing" >&2
    exit 0
    ;;
  Linux)
    ;;
  *)
    exit 0
    ;;
esac

is_running() {
  tailscale status --json 2>/dev/null \
    | grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'
}

if command -v tailscale >/dev/null 2>&1; then
  echo "==> tailscale already installed, skipping setup"
  exit 0
fi

echo "==> Installing tailscale (official installer, latest stable)"
if ! curl -fsSL https://tailscale.com/install.sh | sh; then
  echo "WARNING: tailscale install failed (offline?), continuing" >&2
  exit 0
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "WARNING: tailscale install completed but the CLI is not on PATH; continuing" >&2
  exit 0
fi

if is_running; then
  echo "==> tailscale already up, skipping login"
else
  echo "==> Bringing tailscale up (open the printed URL to authenticate this node)"
  if ! sudo tailscale up --accept-routes=false --ssh=false; then
    echo "WARNING: tailscale login did not complete; continuing" >&2
    exit 0
  fi
fi

# Keep this VPS out of routing and SSH roles. Normal OpenSSH on the public
# interface remains untouched; only explicitly served dev ports use Tailscale.
if ! sudo tailscale set \
  --accept-routes=false \
  --advertise-exit-node=false \
  --advertise-routes= \
  --exit-node= \
  --ssh=false; then
  echo "WARNING: could not enforce the safe Tailscale routing/SSH preferences" >&2
fi
