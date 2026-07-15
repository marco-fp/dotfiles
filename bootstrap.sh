#!/usr/bin/env bash
# Takes a fresh machine (Mac or Linux server) from nothing to a built config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

run_optional() {
  local label="$1"
  shift

  if ! "$@"; then
    echo "WARNING: $label failed; continuing with remaining installers" >&2
  fi
}

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

case "$(uname -s)" in
  Darwin)
    echo "==> Step 3: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
    # darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
    # from the flake this once. After this, rebuild.sh works normally.
    # sudo resets PATH to a secure default that excludes /nix/.../bin, so a
    # freshly installed `nix` would not be found under sudo even though it's
    # on PATH here. Resolve the absolute path first and invoke that instead.
    NIX_BIN="$(command -v nix)"
    sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
      switch --flake ~/.dotfiles#mac
    run_optional "Tailscale setup" "$DIR/install-tailscale.sh"
    # If this fails with "nix: command not found", open a new terminal
    # (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.
    ;;
  Linux)
    echo "==> Step 3: first home-manager switch (release-26.05)"
    # attr is the arch; the config picks up the current $USER/$HOME via --impure
    attr="$(uname -m)-linux"
    nix run github:nix-community/home-manager/release-26.05 -- \
      switch --impure --flake ~/.dotfiles#"$attr" -b hm-backup
    echo "==> Step 4: Tailscale (install + join tailnet, then expose dev ports)"
    run_optional "Tailscale setup" "$DIR/install-tailscale.sh"
    run_optional "Tailscale port exposure" "$DIR/expose-ports.sh"
    echo "==> To make zsh the login shell (home-manager can't do this):"
    echo "    command -v zsh | sudo tee -a /etc/shells && chsh -s \"\$(command -v zsh)\""
    ;;
  *)
    echo "unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

# codex and rust are installed outside Nix (see install-codex.sh / install-rust.sh);
# do it here so a fresh machine has them immediately without a first ./rebuild.sh.
run_optional "Codex setup" "$DIR/install-codex.sh"
run_optional "Rust setup" "$DIR/install-rust.sh"

echo "==> Done. Use ./rebuild.sh for future changes."
