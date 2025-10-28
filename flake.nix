{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence for persistent storage
    impermanence.url = "github:nix-community/impermanence";

    # Emacs packages from GitHub
    gptel-src = {
      url = "github:karthink/gptel/master";
      flake = false;
    };

    macher-src = {
      url = "git+file:///home/czar/projects/macher?rev=4ed3074cacc41abcb8fbe09373753492787ac785";
      flake = false;
    };

    gptel-magit-src = {
      url = "github:ragnard/gptel-magit/main";
      flake = false;
    };
  };

  outputs = {
    self,
    impermanence,
    nixpkgs,
    home-manager,
    gptel-src,
    macher-src,
    gptel-magit-src,
    ...
  } @ inputs: let
    inherit (self) outputs;
    system = "x86_64-linux";

    # Shared configuration values that need to be passed to home-manager
    sharedConfig = {
      keyboard = {
        layout = "us,us";
        variant = "dvp,";
        options = "caps:escape,lv3:ralt_switch_multikey,grp:lalt_lshift_toggle";
      };
    };
  in {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs outputs sharedConfig; };
        modules = [
          ./configuration.nix
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs outputs sharedConfig; };

            # Base configurations
            home-manager.users.czar = import ./users/czar/configuration.nix;
          }
        ];
      };
    };
  };
}
