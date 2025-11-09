{ config, lib, pkgs, ... }:

{
  programs.emacs = lib.mkIf config.programs.emacs.enable {
    extraPackages = epkgs: with epkgs; [
      haskell-mode
      lsp-mode
      lsp-ui
      lsp-haskell
      flycheck
    ];

    extraConfig = ''
      ;; Haskell LSP
      (setq lsp-haskell-server-path "${pkgs.haskell-language-server}/bin/haskell-language-server-wrapper")
      (setq lsp-haskell-formatting-provider "ormolu")

      (add-hook 'haskell-mode-hook #'lsp-deferred)
      (add-hook 'haskell-mode-hook #'flycheck-mode)
    '';
  };
}
