{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    ghc
    stack
    ormolu
    hlint
    haskell-language-server
  ];

  home.file.".stack/config.yaml".text = ''
    resolver: lts-24.11
  '';

  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      haskell-mode
      lsp-haskell
      lsp-mode
      lsp-ui
    ];

    extraConfig = ''
      (use-package lsp-haskell
        :after (lsp-mode haskell-mode)
        :hook (haskell-mode . lsp)
        :config
        (setq lsp-haskell-formatting-provider "ormolu"))
    '';
  };
}
