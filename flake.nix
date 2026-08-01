{
  description = "macOS machine config (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      # One config used on every machine. `bin/sync` always builds `.#default`,
      # so the hostname never has to match. Add per-host attrs here later if
      # two machines ever need to differ.
      username = "gianlo_exa";
    in
    {
      darwinConfigurations.default = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit username; };
        modules = [
          ./darwin.nix

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./home.nix;
            # First switch moves pre-existing ~/.zshrc etc. aside instead of
            # erroring out.
            home-manager.backupFileExtension = "hm-bak";
          }
        ];
      };
    };
}
