#!/usr/bin/env bash
set -euo pipefail

# Keep Homebrew-owned Codex under Homebrew's control. An unchanged cask is not
# reinstalled; an outdated one is upgraded in place.
if command -v brew >/dev/null 2>&1 \
  && brew list --cask codex >/dev/null 2>&1; then
  echo "==> Checking codex version (Homebrew cask)"
  if ! outdated=$(brew outdated --cask --quiet codex); then
    echo "WARNING: could not check codex updates, continuing" >&2
    exit 0
  fi

  if printf '%s\n' "$outdated" | grep -Fxq codex; then
    echo "==> Updating codex (Homebrew cask)"
    brew upgrade --cask codex \
      || echo "WARNING: codex update failed, continuing" >&2
  else
    echo "==> codex already up to date, skipping"
  fi
  exit 0
fi

# Prefer the known standalone path because it may not be on PATH in the shell
# that launched the rebuild.
if [ -x "$HOME/.local/bin/codex" ]; then
  codex_bin="$HOME/.local/bin/codex"
elif command -v codex >/dev/null 2>&1; then
  codex_bin=$(command -v codex)
else
  codex_bin=""
fi

if [ -n "$codex_bin" ]; then
  echo "==> Checking codex version (standalone)"

  current_version=$(
    "$codex_bin" --version 2>/dev/null \
      | sed -n 's/.*[[:space:]]\([0-9][0-9A-Za-z.+-]*\)$/\1/p'
  )
  if [ -z "$current_version" ]; then
    echo "WARNING: could not determine installed codex version, skipping update" >&2
    exit 0
  fi

  if ! release_json=$(curl -fsSL \
    https://api.github.com/repos/openai/codex/releases/latest); then
    echo "WARNING: could not check latest codex version, continuing" >&2
    exit 0
  fi
  latest_version=$(
    printf '%s\n' "$release_json" \
      | sed -n 's/.*"tag_name":[[:space:]]*"rust-v\([^"]*\)".*/\1/p'
  )
  if [ -z "$latest_version" ]; then
    echo "WARNING: could not determine latest codex version, skipping update" >&2
    exit 0
  fi

  if [ "$current_version" = "$latest_version" ]; then
    echo "==> codex $current_version already up to date, skipping"
    exit 0
  fi

  echo "==> Updating codex $current_version -> $latest_version"
  "$codex_bin" update \
    || echo "WARNING: codex update failed, continuing" >&2
  exit 0
fi

# No installation was found. Pre-seed PATH so the official installer writes to
# ~/.local/bin without editing the read-only Home Manager shell profiles.
echo "==> Installing codex (official installer)"
curl -fsSL https://chatgpt.com/codex/install.sh \
  | env CODEX_NON_INTERACTIVE=1 PATH="$HOME/.local/bin:$PATH" sh \
  || echo "WARNING: codex install failed (offline?), continuing" >&2
