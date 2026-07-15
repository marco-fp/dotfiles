# shellcheck shell=bash
set -euo pipefail

catalog="${THEME_CATALOG:-${XDG_CONFIG_HOME:-"$HOME/.config"}/nvim/theme-switcher/themes}"
state_file="${THEME_STATE_FILE:-${XDG_STATE_HOME:-"$HOME/.local/state"}/theme-switcher/current}"
default_theme="nord"

fail() {
  echo "tmux-theme: $*" >&2
  exit 1
}

palette_for() {
  awk -F '|' -v id="$1" '
    $0 !~ /^#/ && NF == 8 && $1 == id {
      printf "%s|%s|%s|%s\n", $5, $6, $7, $8
      exit
    }
  ' "$catalog"
}

[ -r "$catalog" ] || fail "theme catalog not found: $catalog"

case "$#" in
  0)
    selected="$default_theme"
    if [ -r "$state_file" ]; then
      IFS= read -r selected < "$state_file" || true
    fi
    palette="$(palette_for "$selected")"
    if [ -z "$palette" ]; then
      selected="$default_theme"
      palette="$(palette_for "$selected")"
    fi
    ;;
  1)
    selected="$1"
    palette="$(palette_for "$selected")"
    ;;
  *)
    fail "usage: tmux-theme [THEME]"
    ;;
esac

[ -n "$palette" ] || fail "theme '$selected' has no tmux palette"
IFS='|' read -r background foreground muted accent <<< "$palette"

# A theme change must still succeed when no tmux server is running.
if ! tmux list-sessions >/dev/null 2>&1; then
  exit 0
fi

tmux set-option -g status-style "bg=$background,fg=$foreground"
tmux set-option -g status-left " #S "
tmux set-option -g status-left-style "bg=$accent,fg=$background,bold"
tmux set-option -g status-right " #H · %H:%M "
tmux set-option -g status-right-style "bg=$background,fg=$muted"
tmux set-option -g message-style "bg=$accent,fg=$background,bold"
tmux set-option -g mode-style "bg=$accent,fg=$background,bold"
tmux set-option -g pane-border-style "fg=$muted"
tmux set-option -g pane-active-border-style "fg=$accent"
tmux set-window-option -g window-status-format " #I:#W#F "
tmux set-window-option -g window-status-style "bg=$background,fg=$muted"
tmux set-window-option -g window-status-current-format " #I:#W#F "
tmux set-window-option -g window-status-current-style "bg=$accent,fg=$background,bold"
tmux set-window-option -g window-status-activity-style "bg=$background,fg=$accent,bold"
tmux set-window-option -g clock-mode-colour "$accent"
