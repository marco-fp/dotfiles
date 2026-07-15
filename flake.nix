{
  description = "dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    herdr.url = "github:ogulcancelik/herdr";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-homebrew, herdr }:
    let
      # Mac only: the personal machine has a fixed login name. Linux/VPS configs
      # below resolve the username from the invoking environment instead.
      user = "mfernandezpranno";
    in
    {
      darwinConfigurations."mac" = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user inputs; };
        modules = [
          ./configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            # Writable tools such as Codex may atomically replace their managed
            # symlink with a regular file. Keep the newest live file as the
            # backup on every activation instead of failing on a stale backup.
            home-manager.overwriteBackup = true;
            home-manager.extraSpecialArgs = { inherit user inputs; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };

      # Standalone home-manager for remote Linux servers (any distro with Nix).
      # Username-agnostic: keyed by arch, and the config resolves $USER / $HOME
      # of whoever runs the switch. Reading the env needs --impure, which
      # bootstrap.sh / rebuild.sh pass automatically.
      #   x86_64 VPS: home-manager switch --impure --flake ~/.dotfiles#x86_64-linux
      #   ARM VPS:    home-manager switch --impure --flake ~/.dotfiles#aarch64-linux
      homeConfigurations =
        let
          mkHome = system: home-manager.lib.homeManagerConfiguration {
            # import (not legacyPackages) so allowUnfree covers claude-code
            pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
            # username comes from the invoking environment, not a hardcoded name
            extraSpecialArgs = { user = builtins.getEnv "USER"; inherit inputs; };
            modules = [ ./home.nix ];
          };
        in
        {
          "x86_64-linux" = mkHome "x86_64-linux";
          "aarch64-linux" = mkHome "aarch64-linux";
        };
    };
}
