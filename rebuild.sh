#!/usr/bin/env bash
# Apply the current config. Run ./bootstrap.sh first on a fresh machine.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles,
# so this link is load-bearing: without it every linked config breaks.
ln -sfn "$DIR" ~/.dotfiles

case "$(uname -s)" in
  Darwin)
    # resolve an absolute path: sudo resets PATH and would miss the nix bins
    DR="$(command -v darwin-rebuild || true)"
    [ -z "$DR" ] && [ -x /run/current-system/sw/bin/darwin-rebuild ] \
      && DR=/run/current-system/sw/bin/darwin-rebuild
    if [ -z "$DR" ]; then
      echo "darwin-rebuild not found - run ./bootstrap.sh first" >&2
      exit 1
    fi
    exec sudo "$DR" switch --flake ~/.dotfiles#mac
    ;;
  Linux)
    # attr is the arch; the config resolves $USER/$HOME at eval via --impure
    attr="$(uname -m)-linux"
    exec home-manager switch --impure --flake ~/.dotfiles#"$attr" -b hm-backup
    ;;
  *)
    echo "unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac
