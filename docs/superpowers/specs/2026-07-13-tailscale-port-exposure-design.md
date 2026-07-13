# Tailscale-only dev port exposure on the VPS

**Date:** 2026-07-13
**Status:** Approved design, ready for implementation plan

## Goal

Run web/HTTP apps on the Linux VPS and expose a fixed range of ports
(**5000–5010**) that is reachable **only through the tailnet** and **never from
the public internet**, so they can be reviewed from the laptop's browser during
SSH-based development.

The laptop is already on the tailnet; the VPS is not. macOS (the laptop) must
not expose anything — exposure is a Linux-only, VPS-only concern.

## Non-goals (explicitly out of scope)

- **SSH hardening** (restricting port 22 to the tailnet). Deferred: the first
  application risks locking us out of the dev box, so it will be handled
  separately and deliberately, not in this work.
- Non-HTTP services, per-project declarative port config, ad-hoc port helpers,
  Tailscale Funnel (public exposure), or Tailscale SSH.
- Any change to the macOS/laptop Tailscale setup.

## Approach

Use **`tailscale serve`** (HTTPS, one mapping per port) to proxy each tailnet
port to the matching `localhost` port on the VPS. Chosen over binding apps to
the Tailscale IP (needs per-app `--host`, no HTTPS, firewall-dependent) and over
SSH `-L` forwarding (not a stable always-on tailnet address).

"Never public" is guaranteed on three independent layers:

1. Dev apps bind `localhost` — never present on the public interface at all.
2. `tailscale serve` (not `funnel`) is private to the tailnet by default.
3. ufw blocks the public interface for 5000–5010 (defense-in-depth for the case
   where an app is misconfigured to bind `0.0.0.0`).

### Data flow

```
dev app on VPS  →  binds localhost:5003
      │
tailscale serve (set once, persists in tailscaled state across reboots)
      │
https://<vps>.<tailnet>.ts.net:5003  →  localhost:5003   (tailnet-private, valid HTTPS cert)
      │
laptop browser (on tailnet)  →  reviews the app
```

## Components

Three shell scripts in the repo root, following the existing `install-*.sh`
pattern (`set -euo pipefail`, `curl … | sh`, warn-and-continue on failure,
idempotent, non-interactive where possible).

### 1. `install-tailscale.sh` — Linux only

- Early-exit no-op on macOS (`uname -s` = Darwin) — the laptop is untouched.
- Install Tailscale via the official installer (`curl -fsSL https://tailscale.com/install.sh | sh`),
  which installs the **latest stable**. Skip if `tailscale` is already present.
- Bring the node onto the tailnet with `sudo tailscale up` (interactive browser
  auth — prints a login URL to open on the laptop). Skip `up` if already
  authenticated (`tailscale status` reports a backend state of `Running` /
  logged in).
- Needs `sudo`; the user runs bootstrap/rebuild with sudo available.

### 2. `expose-ports.sh` — Linux only, the VPS "expose" addon

- Early-exit no-op on macOS.
- Single constant block at the top for the range: `PORT_START=5000`,
  `PORT_END=5010` — change the range in one place.
- Requires Tailscale to be up (checks `tailscale status`); warn-and-skip if not.
- For each port in the range, assert the `tailscale serve` HTTPS mapping
  `https:<port>` → `http://localhost:<port>` using the **latest** serve CLI
  syntax. Mappings persist in `tailscaled` state, so re-running only re-asserts
  them (idempotent, self-healing).
- **ufw hardening** (Ubuntu/Debian):
  - Ensure SSH stays allowed first (never touch/deny port 22) so enabling ufw
    cannot lock out the current session.
  - Allow 5000–5010 in on the `tailscale0` interface; rely on ufw's default-deny
    incoming for the public interface, so the range is tailnet-reachable and
    publicly blocked.
  - If `ufw` is not installed, print a clear warning and skip the firewall step
    (the localhost-bind + serve-private layers still hold). Extending to other
    firewalls is deferred (YAGNI) since the VPS is Ubuntu/Debian.
- On `tailscale serve` failure that indicates certs are off, print the exact
  one-time admin action needed (see below).

### 3. Wiring — `bootstrap.sh` and `rebuild.sh`

- Call `install-tailscale.sh` then `expose-ports.sh` from the **Linux code path
  only** of both scripts, so macOS never runs them. Scripts also self-guard on
  OS (redundant but safe).
- Runs on **every `./rebuild.sh`** (self-healing, consistent with how
  `install-codex.sh` / `install-rust.sh` are invoked).

## One-time manual step (cannot be scripted without an API key)

`tailscale serve` HTTPS requires **MagicDNS + HTTPS Certificates enabled** in the
tailnet admin console (DNS settings → enable MagicDNS; Settings → enable "HTTPS
Certificates"). `expose-ports.sh` detects the resulting failure and prints what
to enable and where. Also documented in the README.

## Error handling

- All scripts: `set -euo pipefail`, warn-and-continue on network failures
  (offline rebuilds still succeed), matching `install-codex.sh`.
- OS self-guard in each script plus Linux-only call sites.
- `install-tailscale.sh`: skip install if present, skip `up` if authenticated.
- `expose-ports.sh`: skip if Tailscale down; skip firewall if `ufw` absent;
  surface the certs-disabled admin action on serve failure.

## Testing / verification (run on the VPS)

- `tailscale serve status` lists all 11 mappings (5000–5010).
- From the laptop, `curl https://<vps>.<tailnet>.ts.net:5003` against a running
  dev app succeeds with a valid cert.
- The same port on the VPS's **public** IP is refused/unreachable.
- SSH (port 22) stays connected throughout; ufw enable does not drop it.
- Re-running `./rebuild.sh` re-asserts mappings/rules with no errors and no
  duplication (idempotent).

## Documentation

Add a README section (and an "Extending" table row) covering: what the port
range is, how to reach a dev app from the laptop, the one-time MagicDNS/HTTPS
admin toggle, and that exposure is Linux/VPS-only.
