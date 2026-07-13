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
    codex        # macOS gets it via homebrew cask instead
  ] ++ lib.optionals gui [
    nerd-fonts.jetbrains-mono  # patched font, only useful with a GUI terminal
  ];
  fonts.fontconfig.enable = gui;
  home.sessionVariables.EDITOR = "nvim";

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
      co = "codex --full-auto";
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
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
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
