#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local text="$2"
  grep -Fq -- "$text" "$file" \
    || fail "expected '$text' in $file"
}

assert_not_contains() {
  local file="$1"
  local text="$2"
  if grep -Fq -- "$text" "$file"; then
    fail "did not expect '$text' in $file"
  fi
}

new_case() {
  CASE_DIR="$(mktemp -d "$TEST_ROOT/case.XXXXXX")"
  FIXTURE_ROOT="$CASE_DIR/dotfiles"
  FIXTURE_HOME="$CASE_DIR/home"
  MOCK_BIN="$CASE_DIR/bin"
  MOCK_LOG="$CASE_DIR/npx.log"
  OUTPUT="$CASE_DIR/output.log"

  mkdir -p \
    "$FIXTURE_ROOT/home/.codex" \
    "$FIXTURE_HOME/.codex" \
    "$CASE_DIR/home-manager-files/.codex" \
    "$MOCK_BIN"
  cp "$ROOT/install-gsd.sh" "$FIXTURE_ROOT/install-gsd.sh"
  chmod +x "$FIXTURE_ROOT/install-gsd.sh"
  printf 'base = true\n' >"$FIXTURE_ROOT/home/.codex/config.toml"
  ln -s "$FIXTURE_ROOT/home/.codex/config.toml" \
    "$CASE_DIR/home-manager-files/.codex/config.toml"
  ln -s "$CASE_DIR/home-manager-files/.codex/config.toml" \
    "$FIXTURE_HOME/.codex/config.toml"
  : >"$MOCK_LOG"

  cat >"$MOCK_BIN/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_LOG"
if [ -L "$HOME/.codex/config.toml" ]; then
  echo "Codex config was still a symlink" >&2
  exit 90
fi
printf '[agents.gsd-test]\ndescription = "installed"\n\n' >>"$HOME/.codex/config.toml"
if [ "${MOCK_NPX_FAIL:-0}" = "1" ]; then
  exit 42
fi
EOF
  chmod +x "$MOCK_BIN/npx"
}

run_installer() {
  env \
    HOME="$FIXTURE_HOME" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_NPX_FAIL="${MOCK_NPX_FAIL:-0}" \
    PATH="$MOCK_BIN:/usr/bin:/bin" \
    bash "$FIXTURE_ROOT/install-gsd.sh" >"$OUTPUT" 2>&1
}

test_success_syncs_config_and_restores_symlink() {
  new_case
  local original_link
  original_link="$(readlink "$FIXTURE_HOME/.codex/config.toml")"

  run_installer

  [ -L "$FIXTURE_HOME/.codex/config.toml" ] \
    || fail "Codex config symlink was not restored"
  [ "$(readlink "$FIXTURE_HOME/.codex/config.toml")" = "$original_link" ] \
    || fail "Codex config symlink target changed"
  assert_contains "$FIXTURE_ROOT/home/.codex/config.toml" '[agents.gsd-test]'
  assert_contains "$MOCK_LOG" '--yes @opengsd/gsd-core@latest --claude --codex --global'
  [ -n "$(tail -n 1 "$FIXTURE_ROOT/home/.codex/config.toml")" ] \
    || fail "synced config retained a trailing blank line"
}

test_failure_preserves_config_and_restores_symlink() {
  new_case
  local original_link
  original_link="$(readlink "$FIXTURE_HOME/.codex/config.toml")"

  if MOCK_NPX_FAIL=1 run_installer; then
    fail "expected installer failure"
  else
    local exit_code=$?
    [ "$exit_code" -eq 42 ] || fail "expected exit 42, got $exit_code"
  fi

  [ -L "$FIXTURE_HOME/.codex/config.toml" ] \
    || fail "Codex config symlink was not restored after failure"
  [ "$(readlink "$FIXTURE_HOME/.codex/config.toml")" = "$original_link" ] \
    || fail "Codex config symlink target changed after failure"
  assert_not_contains "$FIXTURE_ROOT/home/.codex/config.toml" '[agents.gsd-test]'
}

test_unmanaged_symlink_is_rejected() {
  new_case
  rm "$FIXTURE_HOME/.codex/config.toml"
  printf 'outside = true\n' >"$CASE_DIR/outside.toml"
  ln -s "$CASE_DIR/outside.toml" "$FIXTURE_HOME/.codex/config.toml"

  if run_installer; then
    fail "expected unmanaged symlink rejection"
  fi

  [ -L "$FIXTURE_HOME/.codex/config.toml" ] \
    || fail "unmanaged symlink was not preserved"
  assert_contains "$OUTPUT" "refusing to bypass GSD's symlink guard"
  [ ! -s "$MOCK_LOG" ] || fail "npx ran for an unmanaged symlink"
}

test_success_syncs_config_and_restores_symlink
test_failure_preserves_config_and_restores_symlink
test_unmanaged_symlink_is_rejected

echo "PASS: GSD install script tests"
