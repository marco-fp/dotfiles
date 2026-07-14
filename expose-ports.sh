#!/usr/bin/env bash
set -euo pipefail

# Linux/VPS only: expose local HTTP development servers privately over the
# tailnet. Applications must bind to 127.0.0.1 on a port in this range.
if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

PORT_START=5000
PORT_END=5010

is_running() {
  tailscale status --json 2>/dev/null \
    | grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'
}

if ! command -v tailscale >/dev/null 2>&1 || ! is_running; then
  echo "WARNING: tailscale is not up; skipping port exposure" >&2
  exit 0
fi

harden_firewall() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "WARNING: ufw not found; skipping firewall hardening" >&2
    echo "         Dev apps must remain bound to 127.0.0.1" >&2
    return
  fi

  echo "==> Hardening ufw without changing its defaults or enabled state"

  local ufw_status
  if ! ufw_status="$(sudo ufw status verbose)"; then
    echo "WARNING: could not inspect ufw; skipping all firewall changes" >&2
    return
  fi

  if ! grep -q '^Status: active' <<<"$ufw_status"; then
    echo "WARNING: ufw is inactive; rules were not activated automatically" >&2
    echo "         Dev apps must remain bound to 127.0.0.1" >&2
    return
  fi

  # Preserve ordinary OpenSSH access before applying any live UFW rule. Accept
  # either the distro's OpenSSH profile or an explicit port rule. Never enable,
  # reset, reload, or change UFW defaults from this automation.
  if grep -Eq '^(OpenSSH|22/tcp)[[:space:]].*ALLOW IN' <<<"$ufw_status"; then
    echo "    OpenSSH is already allowed"
  elif ! sudo ufw allow 22/tcp; then
    echo "WARNING: could not guarantee SSH access; skipping all other UFW changes" >&2
    return
  fi

  if ! sudo ufw allow in on tailscale0 to any port "${PORT_START}:${PORT_END}" proto tcp; then
    echo "WARNING: could not add the tailscale0 allow rule" >&2
  fi

  local public_interface
  public_interface="$(ip route show default 2>/dev/null | awk '{ print $5; exit }')" \
    || public_interface=""
  if [ -z "$public_interface" ] || [ "$public_interface" = "tailscale0" ]; then
    echo "WARNING: could not determine the public interface; no public deny rule added" >&2
    return
  fi

  # Insert before any pre-existing broad allow rule for the same ports.
  if ! sudo ufw insert 1 deny in on "$public_interface" to any port "${PORT_START}:${PORT_END}" proto tcp; then
    echo "WARNING: could not add the public-interface deny rule" >&2
  fi
}

harden_firewall

echo "==> Exposing ports ${PORT_START}-${PORT_END} privately with tailscale serve"
for port in $(seq "$PORT_START" "$PORT_END"); do
  # Do not reset Serve: re-assert this range while preserving unrelated config.
  if ! sudo tailscale serve --bg --https="$port" "http://127.0.0.1:${port}"; then
    echo "ERROR: 'tailscale serve' failed for port ${port}" >&2
    echo "Enable HTTPS Certificates for the tailnet using the URL printed by" >&2
    echo "Tailscale (or the admin console), then re-run ./rebuild.sh" >&2
    exit 0
  fi
done
