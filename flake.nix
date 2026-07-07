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
            home-manager.extraSpecialArgs = { inherit user inputs; };
            home-manager.users.${user} = import ./home.nix;
          }
        ];
      };

      # Standalone home-manager for remote Linux servers (any distro with Nix).
      # x86_64 VPS: home-manager switch --flake ~/.dotfiles#mfernandezpranno
      # ARM VPS:   home-manager switch --flake ~/.dotfiles#mfernandezpranno-arm
      homeConfigurations =
        let
          mkHome = system: home-manager.lib.homeManagerConfiguration {
            # import (not legacyPackages) so allowUnfree covers claude-code
            pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
            extraSpecialArgs = { inherit user inputs; };
            modules = [ ./home.nix ];
          };
        in
        {
          "${user}" = mkHome "x86_64-linux";
          "${user}-arm" = mkHome "aarch64-linux";
        };
    };
}
