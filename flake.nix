{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Impermanence for persistent storage
    impermanence.url = "github:nix-community/impermanence";

    # Emacs packages from GitHub
    gptel-src = {
      url = "github:karthink/gptel/master";
      flake = false;
    };

    gptel-magit-src = {
      url = "github:ragnard/gptel-magit/main";
      flake = false;
    };

    claude-code-ide = {
      url = "github:manzaltu/claude-code-ide.el";
      flake = false;
    };

    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";

    # Read-only IMAP MCP server for Claude Code
    imap-readonly-mcp-src = {
      url = "github:AzizMarashly/imap-readonly-mcp";
      flake = false;
    };

    # Claude Code plugins (ralph-loop scripts)
    claude-plugins-public = {
      url = "github:anthropics/claude-plugins-public";
      flake = false;
    };

    # Playwright MCP server
    playwright-mcp-src = {
      url = "github:microsoft/playwright-mcp";
      flake = false;
    };

    # Emacs overlay for native compilation
    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    impermanence,
    nixpkgs,
    home-manager,
    gptel-src,
    gptel-magit-src,
    claude-code-ide,
    claude-code,
    imap-readonly-mcp-src,
    claude-plugins-public,
    playwright-mcp-src,
    emacs-overlay,
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
