# dotfiles

One Nix flake that configures every machine I use:

- **Mac** (local dev): [nix-darwin] + [home-manager] + [nix-homebrew]
  via `darwinConfigurations.mac`
- **Linux servers** (agent VPS over SSH, any distro): standalone home-manager
  via `homeConfigurations.mfernandezpranno` (x86_64) and
  `homeConfigurations.mfernandezpranno-arm` (aarch64)

Both share the same `home.nix`, so the shell, editor, CLI tools, and agent
configuration are identical everywhere.

Adapted from [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles).

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

## How it works

```
flake.nix               inputs + machine configs; username set once here
├── configuration.nix   Mac only: macOS defaults, homebrew casks
└── home.nix            shared: packages, zsh, starship, git, symlinks
    └── home/           the actual config files, symlinked into $HOME
        ├── AGENTS.md               -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md,
        │                              ~/.config/opencode/AGENTS.md
        ├── .claude/settings.json   -> ~/.claude/settings.json
        └── .config/{nvim,wezterm,herdr}/ -> ~/.config/...
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
| Change nvim/wezterm/herdr config | Edit files under `home/.config/` | no |
| Change agent guidance (all CLIs) | Edit `home/AGENTS.md` | no |
| Change Claude Code settings | Edit `home/.claude/settings.json` | no |
| Version a new config dir | Put files in `home/<path>`, add a `link` line in `home.nix` | yes (once) |
| Add a nvim plugin | Add spec under `home/.config/nvim/lua/plugins/` | no (`:Lazy sync`) |
| Support a new Linux user/arch | Add an entry to `homeConfigurations` in `flake.nix` | n/a |
| Update all pinned inputs | `nix flake update`, then `./rebuild.sh` | yes |

Conventions:

- The username lives in exactly one place: `let user = ...` in `flake.nix`.
- Platform differences stay inside `home.nix` guards
  (`pkgs.stdenv.isDarwin` / `isLinux`); everything else is shared.
- Theme is Nord, font is JetBrains Mono (Nerd Font patched), set in
  `home/.config/wezterm/wezterm.lua`, `home/.config/nvim/lua/plugins/ui.lua`,
  and `nerd-fonts.jetbrains-mono` in `home.nix`.
- claude-code comes from the homebrew cask on Mac (self-updates) and from
  nixpkgs on Linux (pinned; `lib.optionals pkgs.stdenv.isLinux`).
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
  `nix flake show` evaluates all configs;
  `nix eval --raw .#homeConfigurations.mfernandezpranno.activationPackage.drvPath`
  cross-evaluates the Linux config from the Mac.

## Notes for agents

- Read `flake.nix` first; it is small and wires everything together.
- Prefer editing `home/` files (instant, no privileges) over Nix options
  (need `./rebuild.sh`, which needs sudo on Mac - ask the user to run it).
- After adding files, `git add` them or Nix will not see them.
- `home/AGENTS.md` is the shared guidance file for Claude Code, Codex, and
  opencode on every machine; edits there propagate to all agent CLIs.
