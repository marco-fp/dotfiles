#!/usr/bin/env bash
set -euo pipefail
# Rust via rustup (not Nix), mirroring install-codex.sh. rustup installs into
# ~/.cargo/bin (on PATH via home.sessionPath). --no-modify-path stops it editing
# the read-only, home-manager-managed shell profiles; -y makes it non-interactive.
# `rustup update` compares channel versions and only downloads changed toolchains.
if [ -x "$HOME/.cargo/bin/rustup" ]; then
  rustup_bin="$HOME/.cargo/bin/rustup"
elif command -v rustup >/dev/null 2>&1; then
  rustup_bin=$(command -v rustup)
else
  rustup_bin=""
fi

if [ -n "$rustup_bin" ]; then
  echo "==> Checking rust toolchain versions (rustup update)"
  "$rustup_bin" update \
    || echo "WARNING: rustup update failed (offline?), continuing" >&2
else
  echo "==> Installing rust (rustup)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path \
    || echo "WARNING: rust install failed (offline?), continuing" >&2
fi
