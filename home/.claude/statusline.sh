#!/bin/sh
# Claude Code status line: model name + context used %
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used" ]; then
    printf '%s | ctx: %.0f%%' "$model" "$used"
else
    printf '%s' "$model"
fi
