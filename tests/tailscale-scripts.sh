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
  MOCK_BIN="$CASE_DIR/bin"
  MOCK_LOG="$CASE_DIR/commands.log"
  OUTPUT="$CASE_DIR/output.log"
  mkdir -p "$MOCK_BIN"
  : >"$MOCK_LOG"

  cat >"$MOCK_BIN/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-s" ] || [ -z "${1:-}" ]; then
  printf '%s\n' "${MOCK_UNAME:-Linux}"
else
  /usr/bin/uname "$@"
fi
EOF

  cat >"$MOCK_BIN/tailscale" <<'EOF'
#!/usr/bin/env bash
printf 'tailscale' >>"$MOCK_LOG"
printf ' %q' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
if [ "${1:-}" = "status" ]; then
  if [ "${MOCK_TS_RUNNING:-1}" = "1" ]; then
    printf '{"BackendState":"Running"}\n'
  else
    printf '{"BackendState":"NeedsLogin"}\n'
  fi
fi
EOF

  cat >"$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo' >>"$MOCK_LOG"
printf ' %q' "$@" >>"$MOCK_LOG"
printf '\n' >>"$MOCK_LOG"
"$@"
EOF

  cat >"$MOCK_BIN/ufw" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "allow" ] && [ "${2:-}" = "22/tcp" ] \
  && [ "${MOCK_FAIL_SSH_ALLOW:-0}" = "1" ]; then
  exit 1
fi
if [ "${1:-}" = "status" ]; then
  if [ "${MOCK_UFW_ACTIVE:-1}" = "1" ]; then
    printf 'Status: active\n'
    if [ "${MOCK_SSH_ALLOWED:-0}" = "1" ]; then
      printf 'OpenSSH ALLOW IN Anywhere\n'
    fi
  else
    printf 'Status: inactive\n'
  fi
fi
EOF

  cat >"$MOCK_BIN/ip" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "route" ]; then
  printf 'default via 192.0.2.1 dev eth0\n'
fi
EOF

  chmod +x "$MOCK_BIN"/*
}

run_mocked() {
  local script="$1"
  env \
    PATH="${MOCK_PATH:-$MOCK_BIN:/usr/bin:/bin}" \
    MOCK_LOG="$MOCK_LOG" \
    MOCK_TS_RUNNING="${MOCK_TS_RUNNING:-1}" \
    MOCK_UFW_ACTIVE="${MOCK_UFW_ACTIVE:-1}" \
    MOCK_SSH_ALLOWED="${MOCK_SSH_ALLOWED:-0}" \
    MOCK_FAIL_SSH_ALLOW="${MOCK_FAIL_SSH_ALLOW:-0}" \
    MOCK_UNAME="${MOCK_UNAME:-Linux}" \
    bash "$ROOT/$script" >"$OUTPUT" 2>&1
}

test_install_failure_is_nonfatal() {
  new_case
  rm "$MOCK_BIN/tailscale"
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 22
EOF
  chmod +x "$MOCK_BIN/curl"
  ln -s /usr/bin/bash "$MOCK_BIN/bash"
  ln -s /usr/bin/sh "$MOCK_BIN/sh"

  MOCK_PATH="$MOCK_BIN" run_mocked install-tailscale.sh

  assert_contains "$OUTPUT" "tailscale install failed"
  assert_not_contains "$MOCK_LOG" "sudo "
}

test_install_running_enforces_safe_preferences() {
  new_case
  run_mocked install-tailscale.sh

  assert_not_contains "$MOCK_LOG" "tailscale up"
  assert_contains "$MOCK_LOG" "sudo tailscale set --accept-routes=false --advertise-exit-node=false --advertise-routes= --exit-node= --ssh=false"
}

test_install_login_uses_safe_flags() {
  new_case
  MOCK_TS_RUNNING=0 run_mocked install-tailscale.sh

  assert_contains "$MOCK_LOG" "sudo tailscale up --accept-routes=false --ssh=false"
  assert_contains "$MOCK_LOG" "sudo tailscale set --accept-routes=false --advertise-exit-node=false --advertise-routes= --exit-node= --ssh=false"
}

test_expose_configures_exact_range_and_safe_firewall() {
  new_case
  run_mocked expose-ports.sh

  local serve_count
  serve_count="$(grep -c '^sudo tailscale serve ' "$MOCK_LOG")"
  [ "$serve_count" -eq 11 ] || fail "expected 11 Serve mappings, got $serve_count"
  assert_contains "$MOCK_LOG" "sudo tailscale serve --bg --https=5000 http://127.0.0.1:5000"
  assert_contains "$MOCK_LOG" "sudo tailscale serve --bg --https=5010 http://127.0.0.1:5010"
  assert_not_contains "$MOCK_LOG" "serve reset"
  assert_contains "$MOCK_LOG" "sudo ufw allow 22/tcp"
  assert_contains "$MOCK_LOG" "sudo ufw allow in on tailscale0 to any port 5000:5010 proto tcp"
  assert_contains "$MOCK_LOG" "sudo ufw insert 1 deny in on eth0 to any port 5000:5010 proto tcp"
  assert_not_contains "$MOCK_LOG" "ufw enable"
  assert_not_contains "$MOCK_LOG" "ufw reset"
  assert_not_contains "$MOCK_LOG" "ufw default"

  local ssh_line
  local status_line
  local next_mutation_line
  status_line="$(grep -n '^sudo ufw status verbose$' "$MOCK_LOG" | cut -d: -f1)"
  ssh_line="$(grep -n '^sudo ufw allow 22/tcp$' "$MOCK_LOG" | cut -d: -f1)"
  next_mutation_line="$(grep -n '^sudo ufw allow in on tailscale0' "$MOCK_LOG" | cut -d: -f1)"
  [ "$status_line" -lt "$ssh_line" ] || fail "UFW was not inspected before mutation"
  [ "$ssh_line" -lt "$next_mutation_line" ] || fail "SSH allow was not the first UFW mutation"
}

test_expose_preserves_existing_openssh_profile() {
  new_case
  MOCK_SSH_ALLOWED=1 run_mocked expose-ports.sh

  assert_contains "$MOCK_LOG" "sudo ufw status verbose"
  assert_not_contains "$MOCK_LOG" "sudo ufw allow 22/tcp"
  assert_contains "$MOCK_LOG" "sudo ufw allow in on tailscale0"
  assert_contains "$OUTPUT" "OpenSSH is already allowed"
}

test_expose_does_not_activate_inactive_ufw() {
  new_case
  MOCK_UFW_ACTIVE=0 run_mocked expose-ports.sh

  assert_contains "$MOCK_LOG" "sudo ufw status verbose"
  assert_not_contains "$MOCK_LOG" "sudo ufw allow 22/tcp"
  assert_not_contains "$MOCK_LOG" "on tailscale0"
  assert_not_contains "$MOCK_LOG" "deny in on eth0"
  assert_not_contains "$MOCK_LOG" "ufw enable"
  assert_contains "$OUTPUT" "ufw is inactive"
}

test_expose_abandons_firewall_if_ssh_cannot_be_allowed() {
  new_case
  MOCK_FAIL_SSH_ALLOW=1 run_mocked expose-ports.sh

  assert_contains "$MOCK_LOG" "sudo ufw allow 22/tcp"
  assert_contains "$MOCK_LOG" "sudo ufw status verbose"
  assert_not_contains "$MOCK_LOG" "on tailscale0"
  assert_not_contains "$MOCK_LOG" "deny in on eth0"
  assert_contains "$OUTPUT" "skipping all other UFW changes"

  local serve_count
  serve_count="$(grep -c '^sudo tailscale serve ' "$MOCK_LOG")"
  [ "$serve_count" -eq 11 ] || fail "Serve setup should continue after UFW is skipped"
}

test_expose_skips_when_tailscale_is_down() {
  new_case
  MOCK_TS_RUNNING=0 run_mocked expose-ports.sh

  assert_not_contains "$MOCK_LOG" "sudo "
  assert_contains "$OUTPUT" "tailscale is not up"
}

test_both_scripts_are_noops_off_linux() {
  new_case
  MOCK_UNAME=Darwin run_mocked install-tailscale.sh
  [ ! -s "$MOCK_LOG" ] || fail "install script ran commands on Darwin"

  new_case
  MOCK_UNAME=Darwin run_mocked expose-ports.sh
  [ ! -s "$MOCK_LOG" ] || fail "expose script ran commands on Darwin"
}

test_install_running_enforces_safe_preferences
test_install_login_uses_safe_flags
test_install_failure_is_nonfatal
test_expose_configures_exact_range_and_safe_firewall
test_expose_preserves_existing_openssh_profile
test_expose_does_not_activate_inactive_ufw
test_expose_abandons_firewall_if_ssh_cannot_be_allowed
test_expose_skips_when_tailscale_is_down
test_both_scripts_are_noops_off_linux

echo "PASS: tailscale script tests"
