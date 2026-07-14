# Tailscale-only Dev Port Exposure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Tailscale on both platforms and expose a fixed range of dev ports (5000–5010) on the VPS over the tailnet only — never the public internet — so web apps can be reviewed from the laptop's browser.

**Architecture:** Mac gets the Tailscale GUI app via a Homebrew cask (`configuration.nix`); Linux gets it via `install-tailscale.sh` (official installer + `tailscale up`). A Linux-only `expose-ports.sh` sets `tailscale serve` HTTPS mappings for each port in the range and adds ufw hardening. Both scripts are wired into the Linux path of `bootstrap.sh`/`rebuild.sh`; the cask applies via the existing `darwin-rebuild`.

**Tech Stack:** Bash, Tailscale (`tailscale serve`), ufw, nix-darwin/Homebrew, home-manager.

> **Confirmed implementation safety amendment (2026-07-14):** Preserve existing
> Serve configuration instead of running `tailscale serve reset`. Preserve SSH
> with an explicit port 22 allow rule, then add an interface-specific public deny
> and `tailscale0` allow. Never enable/reset UFW or change its default policy from
> automation. The live rollout requires a second SSH session.

## Global Constraints

- Port range is **5000–5010**, defined once as `PORT_START=5000` / `PORT_END=5010` at the top of `expose-ports.sh`.
- Shell scripts follow the repo pattern: `#!/usr/bin/env bash`, `set -euo pipefail`, warn-and-continue on failure so an offline/misconfigured run never aborts the parent `bootstrap.sh`/`rebuild.sh` (which also run `set -euo pipefail`). Each new script must **always exit 0** on handled failures.
- Exposure and firewalling are **Linux-only**; every new script early-exits when `uname -s` != `Linux`.
- New scripts must be executable (`chmod +x`) and git-tracked.
- `tailscale serve` (not `funnel`) is used — it is tailnet-private and allows arbitrary ports. Serve config persists in `tailscaled` across reboots.
- One-time manual prerequisite (cannot be scripted without an API key): enable **MagicDNS + HTTPS Certificates** in the tailnet admin console. `expose-ports.sh` surfaces this on failure; README documents it.

---

## File Structure

- `configuration.nix` (modify) — add Tailscale cask to `homebrew.casks` (Mac install).
- `install-tailscale.sh` (create) — Linux: install Tailscale + join tailnet.
- `expose-ports.sh` (create) — Linux/VPS: `tailscale serve` the port range + ufw hardening.
- `bootstrap.sh` (modify) — call both scripts in the Linux arm.
- `rebuild.sh` (modify) — call both scripts in the Linux arm.
- `README.md` (modify) — document install split, exposure, and the one-time admin toggle.

---

## Task 1: macOS Tailscale via Homebrew cask

**Files:**
- Modify: `configuration.nix:38-42` (the `casks = [ … ];` list)

**Interfaces:**
- Produces: Tailscale GUI app managed by Homebrew on the Mac. No script consumes this.

- [ ] **Step 1: Confirm the correct cask token (run on the Mac)**

Homebrew has both a `tailscale` *formula* (CLI/daemon) and a *cask* for the GUI app; the cask token has changed historically. Confirm which token installs the **GUI app**:

Run: `brew info --cask tailscale` and, if that reports it was renamed/disabled, `brew info --cask tailscale-app`
Expected: one of them shows the Tailscale macOS **application** (a `.app`, e.g. "Tailscale.app"). Use that token in Step 2 (below assumes `tailscale`; substitute `tailscale-app` if that is the GUI cask).

- [ ] **Step 2: Add the cask**

Edit `configuration.nix`, adding the confirmed token to the casks list:

```nix
    casks = [
      "wezterm"
      "claude-code"
      "codex"
      "tailscale"
    ];
```

- [ ] **Step 3: Apply and verify (run on the Mac)**

Run: `./rebuild.sh`
Then: `brew list --cask | grep -i tailscale`
Expected: the cask token is listed; the Tailscale menu-bar app is present (the laptop's existing, already-authed install is adopted — `homebrew` here sets no `onActivation.cleanup`, so nothing is removed).

- [ ] **Step 4: Commit**

```bash
git add configuration.nix
git commit -m "Install Tailscale on macOS via Homebrew cask"
```

---

## Task 2: `install-tailscale.sh` (Linux install + join tailnet)

**Files:**
- Create: `install-tailscale.sh`

**Interfaces:**
- Produces: `tailscale` CLI + running `tailscaled`, node authenticated onto the tailnet. `expose-ports.sh` (Task 3) relies on `tailscale status` succeeding.

- [ ] **Step 1: Write the script**

Create `install-tailscale.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# Tailscale on Linux: installed from the official script (latest stable) and
# brought onto the tailnet. macOS gets Tailscale from a homebrew cask instead
# (configuration.nix), so this no-ops there. Needs sudo; bootstrap/rebuild are
# run with sudo available.
if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

if command -v tailscale >/dev/null 2>&1; then
  echo "==> tailscale already installed, skipping install"
else
  echo "==> Installing tailscale (official installer, latest stable)"
  curl -fsSL https://tailscale.com/install.sh | sh \
    || { echo "WARNING: tailscale install failed (offline?), continuing" >&2; exit 0; }
fi

# `tailscale status` exits non-zero when logged out or the daemon is stopped;
# only then run `up` (which prints a browser login URL to authenticate the node).
if tailscale status >/dev/null 2>&1; then
  echo "==> tailscale already up, skipping login"
else
  echo "==> Bringing tailscale up (open the printed URL to authenticate this node)"
  sudo tailscale up
fi
```

- [ ] **Step 2: Syntax check**

Run: `bash -n install-tailscale.sh`
Expected: no output, exit 0.

- [ ] **Step 3: No-op check on this machine if not Linux**

Run (Mac only; skip on Linux): `bash install-tailscale.sh; echo "exit=$?"`
Expected (Mac): prints nothing, `exit=0`.

- [ ] **Step 4: Make executable**

Run: `chmod +x install-tailscale.sh`

- [ ] **Step 5: Integration verify (run on the VPS)**

Run: `./install-tailscale.sh`
Expected: on a fresh VPS, Tailscale installs, then `tailscale up` prints a login URL — open it on the laptop to authenticate. Re-running prints "already installed" / "already up" and makes no changes.
Then: `tailscale status`
Expected: shows this node as `active` on your tailnet.

- [ ] **Step 6: Commit**

```bash
git add install-tailscale.sh
git commit -m "Add install-tailscale.sh: install Tailscale and join tailnet on Linux"
```

---

## Task 3: `expose-ports.sh` (serve the port range + ufw hardening)

**Files:**
- Create: `expose-ports.sh`

**Interfaces:**
- Consumes: a running, authenticated Tailscale node (from Task 2) — checked via `tailscale status`.
- Produces: `https://<host>.<tailnet>.ts.net:<port>` → `http://127.0.0.1:<port>` for each port 5000–5010, tailnet-private; ufw rules allowing the range only on `tailscale0`.

- [ ] **Step 1: Confirm the serve syntax (run on the VPS)**

Run: `tailscale serve --help`
Expected: confirms the flags used below (`--bg`, `--https=<port>`, positional target, `reset`). If the installed version differs, adjust the `tailscale serve` line in Step 2 accordingly before running it.

- [ ] **Step 2: Write the script**

Create `expose-ports.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# VPS-only addon: expose a fixed range of dev ports on the tailnet (HTTPS, via
# `tailscale serve`) and nowhere else. Dev apps bind localhost:<port>; each is
# reachable at https://<host>.<tailnet>.ts.net:<port> from tailnet peers only.
# macOS never exposes anything, so this no-ops there.
if [ "$(uname -s)" != "Linux" ]; then
  exit 0
fi

PORT_START=5000
PORT_END=5010

# Needs the node on the tailnet; skip cleanly if it isn't (e.g. install-tailscale
# was skipped offline, or `up` is not yet authenticated).
if ! tailscale status >/dev/null 2>&1; then
  echo "WARNING: tailscale is not up; skipping port exposure" >&2
  exit 0
fi

echo "==> Exposing ports ${PORT_START}-${PORT_END} on the tailnet (tailscale serve)"
# Reset first so the served set exactly matches the range (no stale mappings if
# the range ever shrinks), then re-add each port. Config persists in tailscaled
# across reboots, so this is set-once and self-healing on re-run.
sudo tailscale serve reset || true
for port in $(seq "$PORT_START" "$PORT_END"); do
  # serve (unlike funnel) is tailnet-private and allows arbitrary ports. --bg
  # persists the mapping; HTTPS is terminated by tailscaled and proxied as plain
  # HTTP to the app on localhost.
  sudo tailscale serve --bg --https="$port" "http://127.0.0.1:${port}" || {
    echo "ERROR: 'tailscale serve' failed for port ${port}." >&2
    echo "If this mentions certificates, enable MagicDNS + HTTPS Certificates in the" >&2
    echo "tailnet admin console (https://login.tailscale.com/admin/dns), then re-run" >&2
    echo "./rebuild.sh." >&2
    exit 0
  }
done

# Defense-in-depth firewall (Ubuntu/Debian ufw): allow the range only on the
# tailscale interface; ufw's default-deny keeps it off the public interface.
if command -v ufw >/dev/null 2>&1; then
  echo "==> Hardening firewall (ufw): tailnet-only access to ${PORT_START}-${PORT_END}"
  # Allow SSH FIRST; if that fails, do NOT enable ufw (avoids SSH lockout).
  sudo ufw allow 22/tcp || {
    echo "WARNING: could not add SSH allow rule; skipping firewall to avoid lockout." >&2
    exit 0
  }
  sudo ufw allow in on tailscale0 to any port "${PORT_START}:${PORT_END}" proto tcp || true
  sudo ufw --force enable || echo "WARNING: 'ufw enable' failed; firewall not active." >&2
  echo "    NOTE: ufw now uses default-deny incoming. Allow other public services"
  echo "    explicitly, e.g. sudo ufw allow 80/tcp."
else
  echo "WARNING: ufw not found; skipping firewall hardening." >&2
  echo "         (localhost-bind + tailnet-private serve still keep ports off the internet.)" >&2
fi
```

- [ ] **Step 3: Syntax check**

Run: `bash -n expose-ports.sh`
Expected: no output, exit 0.

- [ ] **Step 4: No-op check if not Linux (Mac only)**

Run (Mac only): `bash expose-ports.sh; echo "exit=$?"`
Expected (Mac): prints nothing, `exit=0`.

- [ ] **Step 5: Make executable**

Run: `chmod +x expose-ports.sh`

- [ ] **Step 6: Integration verify (run on the VPS, Tailscale already up)**

Run: `./expose-ports.sh`
Then: `tailscale serve status`
Expected: 11 HTTPS mappings, ports 5000–5010, each → `http://127.0.0.1:<port>`.
Then start any HTTP app on the VPS (e.g. `python3 -m http.server 5003`) and from the **laptop** run:
Run: `curl -sSf https://<vps>.<tailnet>.ts.net:5003/ >/dev/null && echo OK`
Expected: `OK`, valid HTTPS (no cert warning).
Then confirm it is NOT public — from a non-tailnet host (or using the VPS public IP): the same port refuses/times out.
Then: `sudo ufw status verbose` shows `22/tcp ALLOW` and `5000:5010/tcp on tailscale0 ALLOW`; SSH stays connected throughout.

- [ ] **Step 7: Idempotency check (run on the VPS)**

Run: `./expose-ports.sh` again
Expected: no errors; `tailscale serve status` still shows exactly the 5000–5010 mappings (no duplicates); ufw reports "Skipping adding existing rule".

- [ ] **Step 8: Commit**

```bash
git add expose-ports.sh
git commit -m "Add expose-ports.sh: tailnet-only HTTPS exposure of dev ports 5000-5010"
```

---

## Task 4: Wire both scripts into bootstrap.sh and rebuild.sh (Linux path)

**Files:**
- Modify: `bootstrap.sh` (Linux arm of the `case`)
- Modify: `rebuild.sh` (Linux arm of the `case`)

**Interfaces:**
- Consumes: `install-tailscale.sh`, `expose-ports.sh` (relative to `$DIR`).
- Produces: both run on every Linux `./bootstrap.sh` and `./rebuild.sh`; macOS never invokes them.

- [ ] **Step 1: Edit `bootstrap.sh`**

In the `Linux)` arm, after the home-manager switch and before the zsh-login hint, add the two calls:

```bash
    nix run github:nix-community/home-manager/release-26.05 -- \
      switch --impure --flake ~/.dotfiles#"$attr" -b hm-backup
    echo "==> Step 4: Tailscale (install + join tailnet, then expose dev ports)"
    "$DIR/install-tailscale.sh"
    "$DIR/expose-ports.sh"
    echo "==> To make zsh the login shell (home-manager can't do this):"
    echo "    command -v zsh | sudo tee -a /etc/shells && chsh -s \"\$(command -v zsh)\""
    ;;
```

- [ ] **Step 2: Edit `rebuild.sh`**

In the `Linux)` arm, add the two calls after the switch and before the codex/rust calls:

```bash
    home-manager switch --impure --flake ~/.dotfiles#"$attr" -b hm-backup
    "$DIR/install-tailscale.sh"
    "$DIR/expose-ports.sh"
    "$DIR/install-codex.sh"
    "$DIR/install-rust.sh"
    ;;
```

- [ ] **Step 3: Syntax check both**

Run: `bash -n bootstrap.sh && bash -n rebuild.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Integration verify (run on the VPS)**

Run: `./rebuild.sh`
Expected: the switch runs, then `install-tailscale.sh` reports "already up", then `expose-ports.sh` re-asserts the 5000–5010 mappings and ufw rules, then codex/rust run — all without aborting.

- [ ] **Step 5: Commit**

```bash
git add bootstrap.sh rebuild.sh
git commit -m "Run Tailscale install + port exposure from Linux bootstrap/rebuild path"
```

---

## Task 5: Document in README.md

**Files:**
- Modify: `README.md` — add a Conventions bullet, an Extending table row, and a short exposure note.

**Interfaces:** none (docs only).

- [ ] **Step 1: Add an Extending table row**

In the "Extending" table, add a row (place it near the Linux-arch row):

```markdown
| Expose a dev app over Tailscale (VPS) | Run it on a port in 5000–5010; open `https://<vps>.<tailnet>.ts.net:<port>` from a tailnet device | no |
```

- [ ] **Step 2: Add a Conventions bullet**

In the "Conventions" bullet list (alongside the codex/rust bullets), add:

```markdown
- Tailscale is installed on both platforms: macOS via the `tailscale` homebrew
  cask (`configuration.nix`), Linux via `install-tailscale.sh` (official
  installer + `tailscale up`), run by bootstrap/rebuild. On the VPS,
  `expose-ports.sh` publishes ports **5000–5010** on the tailnet over HTTPS with
  `tailscale serve` (tailnet-private, never public) and hardens ufw to allow that
  range only on `tailscale0`. Both scripts are Linux-only and no-op on macOS.
  Run a dev app on a port in that range and open
  `https://<vps>.<tailnet>.ts.net:<port>` from any tailnet device.
  **One-time setup:** enable MagicDNS + HTTPS Certificates in the tailnet admin
  console (https://login.tailscale.com/admin/dns) or `tailscale serve` cannot
  issue certs.
```

- [ ] **Step 3: Verify links/format**

Run: `grep -n "expose-ports.sh\|tailscale serve\|5000" README.md`
Expected: the new lines are present and readable.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Document Tailscale install and tailnet-only dev port exposure"
```

---

## Notes on verification honesty

The `bash -n` syntax checks run anywhere. The **integration** steps (Tailscale install, `tailscale up` browser auth, `tailscale serve`, ufw, the `curl` from the laptop) require the real VPS + laptop on the tailnet and the one-time admin-console toggle — they cannot be exercised in an isolated environment. Run those steps on the actual machines and confirm the expected output before checking them off.
