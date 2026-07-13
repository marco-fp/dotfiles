#!/usr/bin/env bash
set -euo pipefail
# Rust via rustup (not Nix), mirroring install-codex.sh. rustup installs into
# ~/.cargo/bin (on PATH via home.sessionPath). --no-modify-path stops it editing
# the read-only, home-manager-managed shell profiles; -y makes it non-interactive.
# Unlike codex, rustup's own update path is `rustup update`, so when it is already
# installed re-run that instead of the web installer (faster, no re-download).
if [ -x "$HOME/.cargo/bin/rustup" ]; then
  echo "==> Updating rust toolchain (rustup update)"
  "$HOME/.cargo/bin/rustup" update \
    || echo "WARNING: rustup update failed (offline?), continuing" >&2
else
  echo "==> Installing rust (rustup)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path \
    || echo "WARNING: rust install failed (offline?), continuing" >&2
fi
