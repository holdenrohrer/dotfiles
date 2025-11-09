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
      ;; Prefer project-provided tools (via direnv) but fallback to Nix store.
      (defvar my-haskell-ghc
        (or (executable-find "ghc")
            "${pkgs.ghc}/bin/ghc")
        "Preferred GHC path, preferring project-provided GHC.")

      (defvar my-haskell-ormolu
        (or (executable-find "ormolu")
            "${pkgs.ormolu}/bin/ormolu")
        "Preferred Ormolu path, preferring project-provided Ormolu.")

      (setq lsp-haskell-server-path "${pkgs.haskell-language-server}/bin/haskell-language-server-wrapper")
      (setq lsp-haskell-formatting-provider "ormolu")

      (add-hook 'haskell-mode-hook #'lsp-deferred)
      (add-hook 'haskell-mode-hook #'flycheck-mode)
    '';
  };
}
