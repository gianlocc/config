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
      # One shared config, built per macOS account. Flakes evaluate purely and
      # cannot read $USER, so each account gets its own attribute and `bin/sync`
      # selects `.#$USER` (falling back to `.#default`).
      #
      # Adding a machine with a different account name = add it to `accounts`.
      accounts = [
        "gianlo_exa"
        "gianlo_personal"
      ];

      mkDarwin = username:
        nix-darwin.lib.darwinSystem {
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
    in
    {
      darwinConfigurations =
        (nixpkgs.lib.genAttrs accounts mkDarwin)
        // { default = mkDarwin (builtins.head accounts); };
    };
}
