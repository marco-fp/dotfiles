{ config, pkgs, lib, user, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # Edit-in-place: the real file stays in the repo, the home path points at it.
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/${path}";
  # GUI-only bits (terminal emulator, patched fonts) install only where a GUI
  # exists. Mac always has one; Linux is headless by default but opts in with
  # GUI=1 (e.g. `GUI=1 ./rebuild.sh`). isDarwin short-circuits the `||`, so the
  # getEnv is never read on Mac and that build stays pure.
  gui = pkgs.stdenv.isDarwin || builtins.getEnv "GUI" == "1";
  themeSwitcher = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      catalog="''${THEME_CATALOG:-''${XDG_CONFIG_HOME:-"$HOME/.config"}/nvim/theme-switcher/themes}"
      state_file="''${THEME_STATE_FILE:-''${XDG_STATE_HOME:-"$HOME/.local/state"}/theme-switcher/current}"
      default_theme="nord"

      fail() {
        echo "theme: $*" >&2
        exit 1
      }

      require_catalog() {
        [ -r "$catalog" ] || fail "theme catalog not found: $catalog"
      }

      theme_exists() {
        awk -F '|' -v id="$1" '
          $0 !~ /^#/ && NF >= 4 && $1 == id { found = 1 }
          END { exit !found }
        ' "$catalog"
      }

      theme_label() {
        awk -F '|' -v id="$1" '
          $0 !~ /^#/ && NF >= 4 && $1 == id { print $2; exit }
        ' "$catalog"
      }

      current_theme() {
        local current="$default_theme"

        if [ -r "$state_file" ]; then
          IFS= read -r current < "$state_file" || true
        fi
        if ! theme_exists "$current"; then
          current="$default_theme"
        fi

        printf '%s\n' "$current"
      }

      show_theme() {
        local selected="$1"
        printf '%s (%s)\n' "$(theme_label "$selected")" "$selected"
      }

      write_theme() {
        local selected="$1"

        mkdir -p "$(dirname "$state_file")"
        # Keep the same inode so long-running Neovim file watchers continue to
        # receive every change.
        printf '%s\n' "$selected" > "$state_file"
        show_theme "$selected"
      }

      cycle_theme() {
        local direction="$1"
        local current selected

        current="$(current_theme)"
        selected="$(awk -F '|' -v current="$current" -v direction="$direction" '
          $0 !~ /^#/ && NF >= 4 { themes[++count] = $1 }
          END {
            if (count == 0) exit 1
            position = 1
            for (i = 1; i <= count; i++) {
              if (themes[i] == current) {
                position = i
                break
              }
            }
            if (direction == "next")
              position = (position % count) + 1
            else
              position = ((position + count - 2) % count) + 1
            print themes[position]
          }
        ' "$catalog")" || fail "theme catalog is empty"
        write_theme "$selected"
      }

      usage() {
        cat <<'EOF'
      Usage: theme [current|list|next|prev|set THEME]
      EOF
      }

      require_catalog
      command="''${1:-current}"

      case "$command" in
        current)
          [ "$#" -le 1 ] || { usage >&2; exit 2; }
          show_theme "$(current_theme)"
          ;;
        list)
          [ "$#" -eq 1 ] || { usage >&2; exit 2; }
          current="$(current_theme)"
          awk -F '|' -v current="$current" '
            $0 !~ /^#/ && NF >= 4 {
              marker = ($1 == current) ? "*" : " "
              printf "%s %-12s %s\n", marker, $1, $2
            }
          ' "$catalog"
          ;;
        next|prev)
          [ "$#" -eq 1 ] || { usage >&2; exit 2; }
          cycle_theme "$command"
          ;;
        set)
          [ "$#" -eq 2 ] || { usage >&2; exit 2; }
          theme_exists "$2" || fail "unknown theme '$2'; run 'theme list'"
          write_theme "$2"
          ;;
        help|-h|--help)
          usage
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  home.username = user;
  # Darwin keeps the fixed path; Linux (standalone HM) uses the real home of the
  # invoking user, so it works for any username incl. root (/root). getEnv is
  # lazy - never forced on Darwin, so the Mac build stays pure.
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${user}" else builtins.getEnv "HOME";
  home.stateVersion = "26.05";

  # standalone `home-manager` CLI on Linux servers
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    themeSwitcher
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    marksman  # markdown LSP: cross-file link nav, anchor completion, rename
  ] ++ [
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default  # agent multiplexer
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    claude-code  # macOS gets it via homebrew cask instead
    gcc          # C toolchain: provides `cc`, the linker rust/cargo needs to build
                 # (macOS gets this from the Xcode Command Line Tools instead)
    # codex is not installed via Nix: it ships several releases/week, faster than
    # any Nix channel tracks. It comes from the official installer (install-codex.sh,
    # run by bootstrap/rebuild) into ~/.local/bin, which is on PATH via sessionPath.
  ] ++ lib.optionals gui [
    nerd-fonts.jetbrains-mono  # patched font, only useful with a GUI terminal
  ];
  fonts.fontconfig.enable = gui;
  home.sessionVariables.EDITOR = "nvim";
  # Tools installed outside Nix by their official installers land here; put these
  # on PATH declaratively so the installers never edit the read-only,
  # home-manager-managed shell profiles (~/.zshrc etc).
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"  # codex
    "${config.home.homeDirectory}/.cargo/bin"  # rust (rustup/cargo)
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      gs = "git status";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex";
    };
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Marco Fernandez Pranno";
      email = "mfernandezpranno@gmail.com";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$hostname$directory$git_branch$git_status$cmd_duration$line_break$character";
      hostname.ssh_only = false;
      character = {
        success_symbol = "[>](purple)";
        error_symbol = "[>](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # wezterm is a GUI terminal; only link its config on machines with a GUI
  home.file.".config/wezterm" = lib.mkIf gui { source = link ".config/wezterm"; };
  home.file.".config/nvim".source = link ".config/nvim";
  home.file.".config/herdr".source = link ".config/herdr";
  home.file.".claude/settings.json".source = link ".claude/settings.json";
  home.file.".codex/config.toml".source = link ".codex/config.toml";

  # one AGENTS.md shared by every agent CLI
  home.file.".claude/CLAUDE.md".source = link "AGENTS.md";
  home.file.".codex/AGENTS.md".source = link "AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source = link "AGENTS.md";
}
