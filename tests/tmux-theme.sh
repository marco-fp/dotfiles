#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
THEME_SCRIPT="$ROOT/home/.config/tmux/tmux-theme.sh"
CATALOG="$ROOT/home/.config/nvim/theme-switcher/themes"
TMUX_BIN=${1:-tmux}
TMP=$(mktemp -d)
SOCKET="/tmp/dotfiles-tmux-theme-$$.sock"

cleanup() {
  "$TMUX_BIN" -S "$SOCKET" kill-server >/dev/null 2>&1 || true
  rm -rf "$TMP"
  rm -f "$SOCKET"
}
trap cleanup EXIT

assert_equal() {
  local expected=$1
  local actual=$2
  local description=$3

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s\nexpected: %s\nactual:   %s\n' "$description" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_style() {
  local style
  local expected
  local description=$3

  style=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  expected=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')

  if [[ "$style" != *"$expected"* ]]; then
    printf 'FAIL: %s\nexpected style to contain: %s\nactual:                    %s\n' \
      "$description" "$expected" "$style" >&2
    exit 1
  fi
}

mkdir -p "$TMP/bin"
cat > "$TMP/bin/tmux" <<'EOF'
#!/usr/bin/env bash
exec "$TMUX_TEST_BIN" -S "$TMUX_TEST_SOCKET" "$@"
EOF
chmod +x "$TMP/bin/tmux"

export TMUX_TEST_BIN="$TMUX_BIN"
export TMUX_TEST_SOCKET="$SOCKET"
"$TMUX_BIN" -S "$SOCKET" -f /dev/null new-session -d -s test

PATH="$TMP/bin:$PATH" THEME_CATALOG="$CATALOG" \
  THEME_STATE_FILE="$TMP/current" bash "$THEME_SCRIPT" kanagawa

status_style=$("$TMUX_BIN" -S "$SOCKET" show-option -gv status-style)
current_style=$("$TMUX_BIN" -S "$SOCKET" show-window-option -gv window-status-current-style)
border_style=$("$TMUX_BIN" -S "$SOCKET" show-option -gv pane-active-border-style)

assert_style "$status_style" 'bg=#1F1F28' 'uses the selected background'
assert_style "$status_style" 'fg=#DCD7BA' 'uses the selected foreground'
assert_style "$current_style" 'bg=#7E9CD8' 'highlights the active window'
assert_style "$current_style" 'bold' 'emphasizes the active window'
assert_style "$border_style" 'fg=#7E9CD8' 'highlights the active pane'
assert_equal ' #S ' "$("$TMUX_BIN" -S "$SOCKET" show-option -gv status-left)" \
  'shows the session name'
assert_equal ' #H · %H:%M ' "$("$TMUX_BIN" -S "$SOCKET" show-option -gv status-right)" \
  'shows the host and 24-hour time'

printf '%s\n' catppuccin > "$TMP/current"
PATH="$TMP/bin:$PATH" THEME_CATALOG="$CATALOG" \
  THEME_STATE_FILE="$TMP/current" bash "$THEME_SCRIPT"
current_style=$("$TMUX_BIN" -S "$SOCKET" show-window-option -gv window-status-current-style)
assert_style "$current_style" 'bg=#8AADF4' 'loads the persisted theme when no id is passed'

if PATH="$TMP/bin:$PATH" THEME_CATALOG="$CATALOG" \
  bash "$THEME_SCRIPT" missing > "$TMP/stdout" 2> "$TMP/stderr"; then
  echo 'FAIL: unknown theme succeeded' >&2
  exit 1
fi
if ! grep -q "theme 'missing' has no tmux palette" "$TMP/stderr"; then
  echo 'FAIL: unknown theme did not produce a useful error' >&2
  exit 1
fi

echo 'tmux-theme tests passed'
