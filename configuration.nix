{
 nix.enable = false;

 nixpkgs.config.allowUnfree = true;
 nixpkgs.hostPlatform = "aarch64-darwin";
 
 system.primaryUser = "marcofp";
 system.stateVersion = 6;
}
