#!/usr/bin/env bash
set -euo pipefail

# Linux gets the Tailscale daemon and CLI from the official stable installer.
# macOS uses the Homebrew GUI cask declared in configuration.nix instead.
if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

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
