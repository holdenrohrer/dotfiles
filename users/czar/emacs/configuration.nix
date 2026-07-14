{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  imports = [
    ./sudoedit.nix
    ./gptel.nix
    ./agent-shell.nix
    ./haskell.nix
    ./ocaml.nix
    ./lean.nix
    ./go.nix
    ./live-reload.nix
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
      evil-org
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
      # eat 0.9.4 freezes Emacs in an infinite loop when a double-width glyph
      # (CJK/emoji, e.g. 💾) lands on the terminal's last column — the wide char
      # can't fit, writes nothing, and the auto-wrap check never fires so
      # eat--t-write spins at 100% CPU. Claude Code's TUI triggers it reliably.
      # Not fixed upstream. Patch broadens the wrap condition; see
      # eat-margin-fix.patch and ~/eat-margin-fix/ for the reproducer.
      (eat.overrideAttrs (old: {
        src = pkgs.runCommand "eat-0.9.4.tar" { } ''
          tar xf ${old.src}
          ( cd eat-0.9.4 && patch -p1 < ${./eat-margin-fix.patch} )
          tar cf $out eat-0.9.4
        '';
      }))
      aggressive-indent
      perspective
      ein
      epresent
      svelte-mode
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
    nodePackages.svelte-language-server
  ];

  # Tree-sitter grammars - symlink to Emacs default search path
  home.file.".emacs.d/tree-sitter".source =
    "${pkgs.emacsPackages.treesit-grammars.with-all-grammars}/lib";

}
