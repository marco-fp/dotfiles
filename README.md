# dotfiles

One Nix flake that configures every machine I use:

- **Mac** (local dev): [nix-darwin] + [home-manager] + [nix-homebrew]
  via `darwinConfigurations.mac`
- **Linux servers** (agent VPS over SSH, any distro): standalone home-manager
  via `homeConfigurations.x86_64-linux` and `homeConfigurations.aarch64-linux`,
  which adopt whatever username runs the switch (no per-user config needed)

Both share the same `home.nix`, so the shell, editor, CLI tools, and agent
configuration are identical everywhere.

[nix-darwin]: https://github.com/nix-darwin/nix-darwin
[home-manager]: https://github.com/nix-community/home-manager
[nix-homebrew]: https://github.com/zhaofengli/nix-homebrew

## Quick start

### Fresh machine (Mac or Linux)

```sh
git clone git@github.com:marco-fp/dotfiles.git ~/Code/dotfiles
cd ~/Code/dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs Determinate Nix if missing, symlinks the repo to
`~/.dotfiles`, and runs the first switch (darwin-rebuild on Mac, home-manager
on Linux). On Linux, finish by making zsh the login shell:

```sh
command -v zsh | sudo tee -a /etc/shells && chsh -s "$(command -v zsh)"
```

### Every later change

```sh
./rebuild.sh
```

## Private VPS development ports

On Linux, bootstrap/rebuild installs Tailscale and privately publishes HTTPS
ports **5000–5010** with `tailscale serve`. Run each development app on
`127.0.0.1:<port>`, then open this URL from a device on the same tailnet:

```text
https://remote.taile42e61.ts.net:<port>/
```

The first run prints a URL for authenticating the VPS. Tailscale Serve also
requires HTTPS Certificates for the tailnet; if they are disabled, follow the
consent URL printed by `tailscale serve` and re-run `./rebuild.sh`.

The automation does not enable Tailscale SSH, advertise or accept routes, use
Funnel, or replace normal OpenSSH. It preserves public SSH on port 22 before
adding UFW rules that allow the development range on `tailscale0` and deny it
on the VPS's public interface. It never enables, resets, or changes UFW's
default policy. Keep a second SSH connection open during the first deployment
and verify `sudo ufw status verbose` before closing the original session.

## How it works

```
flake.nix               inputs + machine configs; username set once here
├── configuration.nix   Mac only: macOS defaults, homebrew casks
└── home.nix            shared: packages, zsh, starship, git, symlinks
    └── home/           the actual config files, symlinked into $HOME
        ├── AGENTS.md               -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md,
        │                              ~/.config/opencode/AGENTS.md
        ├── .claude/settings.json   -> ~/.claude/settings.json
        ├── .codex/config.toml      -> ~/.codex/config.toml
        ├── .config/{nvim,wezterm,herdr}/ -> ~/.config/...
        └── .config/tmux/tmux-theme.sh  -> packaged by home.nix
```

Two different mechanisms are in play:

1. **Nix-managed options** (`home.nix`, `configuration.nix`): packages,
   shell setup, macOS defaults. Changing these requires `./rebuild.sh`.
2. **Edit-in-place config files** (`home/`): linked into `$HOME` with
   `mkOutOfStoreSymlink`, which means the symlink resolves through
   `~/.dotfiles` to the *live repo checkout*, not a store copy. Editing
   these files applies instantly - no rebuild. This also means apps that
   write their own config (e.g. Claude Code changing its theme, lazy.nvim
   updating `lazy-lock.json`) dirty the git tree; review and commit those
   changes like any other edit.

Because the symlinks resolve through `~/.dotfiles`, that link (created by
bootstrap/rebuild) is load-bearing: if you move this repo, run `./rebuild.sh`
again or every linked config silently breaks.

Nix flakes only see **git-tracked files**. If a build fails with
"path ... is not tracked by Git", `git add` the new file and retry.

## Extending

| I want to... | Do this | Rebuild? |
|---|---|---|
| Add a CLI tool everywhere | Add to `home.packages` in `home.nix` | yes |
| Add a Mac GUI app | Add cask to `homebrew.casks` in `configuration.nix` | yes |
| Add a shell alias | `programs.zsh.shellAliases` in `home.nix` | yes |
| Change tmux behavior | `programs.tmux` in `home.nix` | yes |
| Change nvim/wezterm/herdr config | Edit files under `home/.config/` | no |
| Change agent guidance (all CLIs) | Edit `home/AGENTS.md` | no |
| Change Claude Code settings | Edit `home/.claude/settings.json` | no |
| Version a new config dir | Put files in `home/<path>`, add a `link` line in `home.nix` | yes (once) |
| Add a nvim plugin | Add spec under `home/.config/nvim/lua/plugins/` | no (`:Lazy sync`) |
| Expose a dev app over Tailscale (VPS) | Bind it to `127.0.0.1` on port 5000–5010 and use its private `*.ts.net` URL | no |
| Run on a new Linux arch | Add an arch entry to `homeConfigurations` in `flake.nix` | n/a |
| Update all pinned inputs | `nix flake update`, then `./rebuild.sh` | yes |

Conventions:

- The Mac username is set once (`let user = ...` in `flake.nix`); Linux/VPS
  configs derive the username from `$USER` at switch time (needs `--impure`,
  which `bootstrap.sh`/`rebuild.sh` pass for you).
- Platform differences stay inside `home.nix` guards
  (`pkgs.stdenv.isDarwin` / `isLinux`); everything else is shared.
- GUI-only bits (wezterm config, patched fonts) install only where a GUI
  exists: Mac always, Linux never unless you switch with `GUI=1` (e.g.
  `GUI=1 ./rebuild.sh`). Gated by `gui` in `home.nix`.
- WezTerm, Neovim, and tmux share a persistent theme selection.
  `Cmd+Shift+T` cycles all three in sync; `theme next|prev|set|list` works from
  the shell, and Neovim has `:ThemeNext`, `:ThemePrev`, and `:Theme <name>`.
  The font is JetBrains Mono (Nerd Font patched), configured in
  `home/.config/wezterm/wezterm.lua` and `nerd-fonts.jetbrains-mono` in
  `home.nix`.
- tmux uses the standard `Ctrl-b` prefix. Run `t` to create or reattach the
  persistent `main` session. Prefix + `h/j/k/l` moves between panes, uppercase
  `H/J/K/L` resizes them, `r` reloads the config, and `[` enters vi copy mode
  (`v` selects and `y` copies). Mouse selection and `y` use OSC 52, so copied
  text reaches the local WezTerm clipboard even when tmux runs on a VPS over
  SSH. Windows and splits start in the active pane's directory.
- claude-code comes from the homebrew cask on Mac (self-updates) and from
  nixpkgs on Linux (pinned; `lib.optionals pkgs.stdenv.isLinux`).
- codex is **not** managed by Nix: macOS uses the Homebrew cask, while Linux
  installs the standalone release into `~/.local/bin`. `install-codex.sh` asks
  Homebrew whether its cask is outdated; for standalone installs, it compares
  the installed version with the official latest GitHub release before running
  `codex update`. It installs only when codex is absent and never reinstalls an
  unchanged version. codex rewrites its own `config.toml` with machine-specific
  `[projects.*]` trust entries; leave those uncommitted.
- GSD Core is installed for Claude Code and Codex with `./install-gsd.sh`.
  The upstream GSD installer rejects a symlinked `~/.codex/config.toml`, so
  the wrapper temporarily materializes that file, runs the official `npx`
  installer, syncs the generated config back into `home/.codex/config.toml`,
  and restores the Home Manager symlink. Re-run the wrapper to update GSD.
- rust is **not** managed by Nix either: `install-rust.sh` runs rustup
  (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`) with
  `--no-modify-path` into `~/.cargo/bin` (on PATH via `home.sessionPath`).
  bootstrap/rebuild install it when absent and run `rustup update` otherwise;
  rustup only downloads toolchains whose channel version changed.
- `install-tailscale.sh` leaves an existing macOS CLI or app bundle untouched
  and otherwise installs the `tailscale-app` Homebrew cask. On Linux it uses
  the official stable installer. Linux bootstrap/rebuild also runs
  `expose-ports.sh`; macOS never exposes the development port range. Tailscale,
  port exposure, Codex, and Rust are independent optional steps, so one failing
  does not prevent the remaining installers from running.
- herdr comes from its own flake input on both platforms.

## Troubleshooting

- **`sudo: darwin-rebuild: command not found`**: sudo resets PATH;
  `rebuild.sh` already resolves the absolute path. On a machine where
  nix-darwin was never activated, run `./bootstrap.sh` instead.
- **home-manager refuses to overwrite an existing file**: first-run
  collisions are backed up as `*.hm-backup` (`backupFileExtension`). If a
  later switch complains a backup already exists, delete the stale
  `*.hm-backup` file and re-run.
- **Existing Homebrew "in the way" on first Mac switch**:
  `nix-homebrew.autoMigrate = true` (already set) migrates the install
  while keeping installed packages.
- **Stale shell after a switch**: open a fresh terminal. Long-lived shells
  keep guard vars (`__NIX_DARWIN_SET_ENVIRONMENT_DONE`,
  `__HM_SESS_VARS_SOURCED`) that prevent re-sourcing the new PATH.
- **Dangling completions after brew migration** (e.g.
  `compinit: no such file or directory ... _brew`): the old Homebrew clone
  owned that file. Repoint it through the stable nix-homebrew path:
  `ln -sfn ../../../Library/Homebrew/../../completions/zsh/_brew /opt/homebrew/share/zsh/site-functions/_brew`
- **Validate without switching**:
  `nix flake show --impure` evaluates all configs;
  `nix eval --impure --raw .#homeConfigurations.x86_64-linux.activationPackage.drvPath`
  cross-evaluates the Linux config from the Mac.

## Notes for agents

- Read `flake.nix` first; it is small and wires everything together.
- Prefer editing `home/` files (instant, no privileges) over Nix options
  (need `./rebuild.sh`, which needs sudo on Mac - ask the user to run it).
- After adding files, `git add` them or Nix will not see them.
- `home/AGENTS.md` is the shared guidance file for Claude Code, Codex, and
  opencode on every machine; edits there propagate to all agent CLIs.
