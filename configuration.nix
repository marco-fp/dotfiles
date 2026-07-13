{ user, ... }:
{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";
  system.stateVersion = 6;

  # No dock.* or _HIHideMenuBar keys here on purpose: managing them makes
  # every activation restart the Dock process, which kills cmd-tab and the
  # Dock itself until manually kickstarted. Dock behavior stays user-managed.
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      AppleShowAllExtensions = true;
    };
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };

  nix-homebrew = {
    enable = true;
    inherit user;
    # take over the pre-existing /opt/homebrew install, keeping its packages
    autoMigrate = true;
  };
  homebrew = {
    enable = true;
    # no onActivation.cleanup: pre-existing brews (ghostty, orbstack, ...)
    # are not declared here yet and must survive activation
    casks = [
      "wezterm"
      "claude-code"
      "codex"
    ];
  };
}
