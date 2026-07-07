{ config, pkgs, lib, user, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # Edit-in-place: the real file stays in the repo, the home path points at it.
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/${path}";
in
{
  home.username = user;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
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
    nerd-fonts.jetbrains-mono
  ] ++ [
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default  # agent multiplexer
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    claude-code  # macOS gets it via homebrew cask instead
  ];
  fonts.fontconfig.enable = true;
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

  home.file.".config/wezterm".source = link ".config/wezterm";
  home.file.".config/nvim".source = link ".config/nvim";
  home.file.".config/herdr".source = link ".config/herdr";
  home.file.".claude/settings.json".source = link ".claude/settings.json";

  # one AGENTS.md shared by every agent CLI
  home.file.".claude/CLAUDE.md".source = link "AGENTS.md";
  home.file.".codex/AGENTS.md".source = link "AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source = link "AGENTS.md";
}
