#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
THEME_BIN=${1:-theme}
CATALOG="$ROOT/home/.config/nvim/theme-switcher/themes"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tmux"

run_theme() {
  TMUX_TMPDIR="$TMP/tmux" THEME_CATALOG="$CATALOG" \
    THEME_STATE_FILE="$TMP/current" "$THEME_BIN" "$@"
}

assert_equal() {
  local expected=$1
  local actual=$2
  local description=$3

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$description" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_equal 'Nord (nord)' "$(run_theme current)" 'defaults to Nord'
assert_equal 'Nord (nord)' "$(run_theme)" 'supports the default command'
assert_equal 'Tokyo Night Moon (tokyonight)' "$(run_theme next)" 'cycles forward'
assert_equal 'Nord (nord)' "$(run_theme prev)" 'cycles backward'
assert_equal 'Rosé Pine Moon (rose-pine)' "$(run_theme prev)" 'wraps backward'
assert_equal 'Nord (nord)' "$(run_theme next)" 'wraps forward'
assert_equal 'Kanagawa Wave (kanagawa)' "$(run_theme set kanagawa)" 'sets a theme by id'
assert_equal 'kanagawa' "$(< "$TMP/current")" 'persists the selected id'

if run_theme set missing > "$TMP/stdout" 2> "$TMP/stderr"; then
  echo 'FAIL: unknown theme succeeded' >&2
  exit 1
fi
if ! grep -q "unknown theme 'missing'" "$TMP/stderr"; then
  echo 'FAIL: unknown theme did not produce a useful error' >&2
  exit 1
fi

echo 'theme-switcher tests passed'
