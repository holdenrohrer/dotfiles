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
      ;; Start LSP only after tools are available via direnv; fallback checks happen at hook time.
      (setq lsp-haskell-server-path "${pkgs.haskell-language-server}/bin/haskell-language-server-wrapper")
      (setq lsp-haskell-formatting-provider "ormolu")

      (defun my-haskell--retry-lsp-after-direnv ()
        "Retry starting HLS after direnv updates this buffer."
        (remove-hook 'direnv-update-environment-hook #'my-haskell--retry-lsp-after-direnv t)
        (if (executable-find "ghc")
            (progn
              (lsp-deferred)
              (unless (executable-find "ormolu")
                (message "Ormolu not found in PATH; HLS formatting may fail unless your devShell provides ormolu.")))
          (message "GHC still not found after direnv update. Ensure your project devShell provides ghc.")))

      (defun my-haskell--start-lsp-when-ready ()
        "Start HLS if ghc is available; otherwise wait for direnv to load the project environment."
        (if (executable-find "ghc")
            (lsp-deferred)
          (message "GHC not found in PATH yet; waiting for direnv...")
          (add-hook 'direnv-update-environment-hook #'my-haskell--retry-lsp-after-direnv nil t)))

      (add-hook 'haskell-mode-hook #'my-haskell--start-lsp-when-ready)
      (add-hook 'haskell-mode-hook #'flycheck-mode)
    '';
  };
}
