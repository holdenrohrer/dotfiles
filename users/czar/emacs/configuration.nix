{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  imports = [
    ./sudoedit.nix
    ./gptel.nix
    ./haskell.nix
    ./ocaml.nix
    ./lean.nix
    ./go.nix
  ];

  # Keep an Emacs server running so emacsclient always has a socket.
  # Start after graphical session so it inherits WAYLAND_DISPLAY etc.
  services.emacs = {
    enable = true;
    startWithUserSession = "graphical";
  };

  # Emacs configuration
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;

    extraPackages = epkgs: with epkgs; [
      evil
      evil-collection
      magit
      magit-section
      transient
      use-package
      envrc
      visual-fill-column
      sudo-edit
      dtrt-indent
      nix-mode
      undo-tree
      meson-mode
      flycheck
      git-timemachine
      eat
      aggressive-indent
      perspective
      ein
      (melpaBuild {
        pname = "claude-code-ide";
        version = "0.0.1";
        src = inputs.claude-code-ide;
        recipe = pkgs.writeText "recipe" ''
          (claude-code-ide :repo "manzaltu/claude-code-ide.el" :fetcher github)
        '';
        packageRequires = [ transient websocket web-server ];
      })
    ];

    extraConfig = builtins.readFile ./init.el;
  };

  # Core CLI tools and language servers
  home.packages = with pkgs; [
    direnv
    # Language servers for eglot
    pyright
    nodePackages.typescript-language-server
    nodePackages.typescript
    nixd
    nodePackages.bash-language-server
  ];

  # Tree-sitter grammars - symlink to Emacs default search path
  home.file.".emacs.d/tree-sitter".source =
    "${pkgs.emacsPackages.treesit-grammars.with-all-grammars}/lib";

}
