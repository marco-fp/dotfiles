#!/usr/bin/env bash
set -euo pipefail
# codex ships several releases/week - faster than any Nix channel tracks - so it
# is installed from the official script into ~/.local/bin instead of via Nix.
# Pre-seed PATH so the installer sees ~/.local/bin already present and does NOT
# try to edit the read-only, home-manager-managed ~/.zshrc.
echo "==> Installing/updating codex (official installer)"
curl -fsSL https://chatgpt.com/codex/install.sh \
  | env CODEX_NON_INTERACTIVE=1 PATH="$HOME/.local/bin:$PATH" sh \
  || echo "WARNING: codex install failed (offline?), continuing" >&2
