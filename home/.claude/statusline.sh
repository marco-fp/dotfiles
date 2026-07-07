#!/bin/sh
# Claude Code status line: model | git branch | context used %
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // .model.id // "unknown"')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Current git branch (worktree-aware), resolved from the session cwd.
branch=""
if [ -n "$cwd" ]; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
fi
if [ -z "$branch" ]; then
    branch=$(echo "$input" | jq -r '.worktree.branch // .workspace.git_worktree // empty')
fi

out="$model"
[ -n "$branch" ] && out="$out | $branch"
[ -n "$used" ] && out="$out | ctx:$(printf '%.0f' "$used")%"

echo "$out"
