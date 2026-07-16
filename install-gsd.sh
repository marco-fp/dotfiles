#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CODEX_CONFIG="$HOME/.codex/config.toml"
REPO_CODEX_CONFIG="$ROOT/home/.codex/config.toml"
GSD_PACKAGE="@opengsd/gsd-core@latest"

codex_link=""
codex_target=""
sync_temp=""

resolve_file() {
  local current="$1"
  local depth=0
  local directory
  local link

  while [ -L "$current" ]; do
    depth=$((depth + 1))
    if [ "$depth" -gt 40 ]; then
      echo "ERROR: too many symlinks while resolving $1" >&2
      return 1
    fi

    link="$(readlink "$current")"
    if [[ "$link" = /* ]]; then
      current="$link"
    else
      directory="$(cd -P "$(dirname "$current")" && pwd)"
      current="$directory/$link"
    fi
  done

  directory="$(cd -P "$(dirname "$current")" && pwd)"
  printf '%s/%s\n' "$directory" "$(basename "$current")"
}

restore_codex_config() {
  local exit_code=$?

  if [ -n "$sync_temp" ] && [ -e "$sync_temp" ]; then
    rm -f "$sync_temp" || exit_code=1
  fi

  if [ -n "$codex_link" ]; then
    if ! rm -f "$CODEX_CONFIG"; then
      echo "ERROR: could not remove temporary $CODEX_CONFIG" >&2
      exit_code=1
    elif ! ln -s "$codex_link" "$CODEX_CONFIG"; then
      echo "ERROR: could not restore the original $CODEX_CONFIG symlink" >&2
      exit_code=1
    fi
  fi

  trap - EXIT
  exit "$exit_code"
}

trap restore_codex_config EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -L "$CODEX_CONFIG" ]; then
  codex_link="$(readlink "$CODEX_CONFIG")"
  codex_target="$(resolve_file "$CODEX_CONFIG")"
  expected_target="$(resolve_file "$REPO_CODEX_CONFIG")"

  if [ "$codex_target" != "$expected_target" ]; then
    echo "ERROR: refusing to bypass GSD's symlink guard for an unmanaged target:" >&2
    echo "  $codex_target" >&2
    echo "Expected the symlink to resolve to:" >&2
    echo "  $expected_target" >&2
    exit 1
  fi
  if [ ! -f "$codex_target" ] || [ ! -w "$codex_target" ]; then
    echo "ERROR: Codex config target is not a writable regular file: $codex_target" >&2
    exit 1
  fi

  echo "==> Temporarily materializing $CODEX_CONFIG for the GSD installer"
  rm "$CODEX_CONFIG"
  cp -p "$codex_target" "$CODEX_CONFIG"
fi

echo "==> Installing/updating GSD Core for Claude Code and Codex"
npx --yes "$GSD_PACKAGE" --claude --codex --global

if [ -n "$codex_link" ]; then
  target_dir="$(dirname "$codex_target")"
  target_name="$(basename "$codex_target")"
  sync_temp="$(mktemp "$target_dir/.${target_name}.gsd.XXXXXX")"
  cp -p "$codex_target" "$sync_temp"
  # Command substitution removes all trailing newlines; printf restores exactly
  # one so the generated TOML does not leave a whitespace error in the git diff.
  printf '%s\n' "$(<"$CODEX_CONFIG")" >"$sync_temp"
  mv -f "$sync_temp" "$codex_target"
  sync_temp=""
  echo "==> Synced GSD's Codex configuration into $REPO_CODEX_CONFIG"
fi
