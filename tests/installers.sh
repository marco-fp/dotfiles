#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file=$1
  local text=$2
  grep -Fq -- "$text" "$file" || fail "expected '$text' in $file"
}

assert_not_contains() {
  local file=$1
  local text=$2
  if grep -Fq -- "$text" "$file"; then
    fail "did not expect '$text' in $file"
  fi
}

new_case() {
  CASE_DIR=$(mktemp -d "$TEST_ROOT/case.XXXXXX")
  MOCK_BIN="$CASE_DIR/bin"
  MOCK_LOG="$CASE_DIR/commands.log"
  OUTPUT="$CASE_DIR/output.log"
  HOME_DIR="$CASE_DIR/home"
  mkdir -p "$MOCK_BIN" "$HOME_DIR"
  : >"$MOCK_LOG"

  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl' >>"$MOCK_LOG"
printf ' %q' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
case "$*" in
  *api.github.com/repos/openai/codex/releases/latest*)
    printf '{"tag_name":"rust-v%s"}\n' "${MOCK_CODEX_LATEST_VERSION:-0.144.4}"
    ;;
  *)
    printf ':\n'
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/curl"
}

add_brew() {
  cat >"$MOCK_BIN/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew' >>"$MOCK_LOG"
printf ' %q' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"

case "${1:-}" in
  list)
    [ "${MOCK_BREW_CODEX_INSTALLED:-0}" = 1 ]
    ;;
  outdated)
    if [ "${MOCK_BREW_CODEX_OUTDATED:-0}" = 1 ]; then
      printf 'codex\n'
    fi
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/brew"
}

run_installer() {
  local script=$1
  env \
    HOME="$HOME_DIR" \
    PATH="$MOCK_BIN:/usr/bin:/bin" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_BREW_CODEX_INSTALLED="${MOCK_BREW_CODEX_INSTALLED:-0}" \
    MOCK_BREW_CODEX_OUTDATED="${MOCK_BREW_CODEX_OUTDATED:-0}" \
    MOCK_CODEX_CURRENT_VERSION="${MOCK_CODEX_CURRENT_VERSION:-0.144.4}" \
    MOCK_CODEX_LATEST_VERSION="${MOCK_CODEX_LATEST_VERSION:-0.144.4}" \
    bash "$ROOT/$script" >"$OUTPUT" 2>&1
}

test_brew_codex_current_skips_upgrade_and_installer() {
  new_case
  add_brew
  MOCK_BREW_CODEX_INSTALLED=1 run_installer install-codex.sh

  assert_contains "$MOCK_LOG" "brew outdated --cask --quiet codex"
  assert_not_contains "$MOCK_LOG" "brew upgrade"
  assert_not_contains "$MOCK_LOG" "curl "
  assert_contains "$OUTPUT" "codex already up to date"
}

test_brew_codex_outdated_upgrades() {
  new_case
  add_brew
  MOCK_BREW_CODEX_INSTALLED=1 MOCK_BREW_CODEX_OUTDATED=1 \
    run_installer install-codex.sh

  assert_contains "$MOCK_LOG" "brew upgrade --cask codex"
  assert_not_contains "$MOCK_LOG" "curl "
}

add_standalone_codex() {
  mkdir -p "$HOME_DIR/.local/bin"
  cat >"$HOME_DIR/.local/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf 'codex' >>"$MOCK_LOG"
printf ' %q' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"

if [ "${1:-}" = --version ]; then
  printf 'codex-cli %s\n' "${MOCK_CODEX_CURRENT_VERSION:-0.144.4}"
fi
EOF
  chmod +x "$HOME_DIR/.local/bin/codex"
}

test_standalone_codex_current_skips_self_update() {
  new_case
  add_standalone_codex

  run_installer install-codex.sh

  assert_contains "$MOCK_LOG" "codex --version"
  assert_contains "$MOCK_LOG" "api.github.com/repos/openai/codex/releases/latest"
  assert_not_contains "$MOCK_LOG" "codex update"
  assert_contains "$OUTPUT" "codex 0.144.4 already up to date"
}

test_standalone_codex_outdated_uses_self_update() {
  new_case
  add_standalone_codex

  MOCK_CODEX_CURRENT_VERSION=0.143.0 \
    run_installer install-codex.sh

  assert_contains "$MOCK_LOG" "codex --version"
  assert_contains "$MOCK_LOG" "codex update"
  assert_contains "$OUTPUT" "Updating codex 0.143.0 -> 0.144.4"
}

test_missing_codex_runs_installer() {
  new_case
  run_installer install-codex.sh

  assert_contains "$MOCK_LOG" "curl -fsSL https://chatgpt.com/codex/install.sh"
}

test_existing_rustup_checks_for_updates() {
  new_case
  mkdir -p "$HOME_DIR/.cargo/bin"
  cat >"$HOME_DIR/.cargo/bin/rustup" <<'EOF'
#!/usr/bin/env bash
printf 'rustup' >>"$MOCK_LOG"
printf ' %q' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
EOF
  chmod +x "$HOME_DIR/.cargo/bin/rustup"

  run_installer install-rust.sh

  assert_contains "$MOCK_LOG" "rustup update"
  assert_not_contains "$MOCK_LOG" "curl "
}

test_missing_rustup_runs_installer() {
  new_case
  run_installer install-rust.sh

  assert_contains "$MOCK_LOG" "curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs"
}

test_brew_codex_current_skips_upgrade_and_installer
test_brew_codex_outdated_upgrades
test_standalone_codex_current_skips_self_update
test_standalone_codex_outdated_uses_self_update
test_missing_codex_runs_installer
test_existing_rustup_checks_for_updates
test_missing_rustup_runs_installer

echo "PASS: installer tests"
