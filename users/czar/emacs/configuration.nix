{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  imports = [
    ./aider.nix
    ./sudoedit.nix
    ./gptel.nix
    ./haskell.nix
    ./lean.nix
  ];

  # Emacs configuration
  programs.emacs = {
    enable = true;

    extraPackages = epkgs: with epkgs; [
      evil
      evil-collection
      magit
      transient
      use-package
      direnv
      visual-fill-column
      sudo-edit
      dtrt-indent
      nix-mode
      undo-tree
      meson-mode
      lsp-mode
      lsp-ui
      flycheck
      git-timemachine
    ];

    extraConfig = ''
      ;; Basic dark theme
      (load-theme 'wombat t)

      ;; Enable emacsclient
      (require 'server)
      (unless (server-running-p)
        (server-start))

      ;; Indent with spaces, default to 4
      (setq-default indent-tabs-mode nil)
      (setq-default tab-width 4)
      (setq indent-line-function 'indent-relative)

      (add-hook 'before-save-hook 'whitespace-cleanup)

      ; Fold text at word boundaries
      ; And use the visual-fill-column package to
      (use-package visual-fill-column
        :config
        (setq-default fill-column 100)
        (global-visual-fill-column-mode 1)
        (global-visual-line-mode 1))

      ;; Language modes
      (use-package nix-mode
        :mode "\\.nix\\'")
      (use-package meson-mode
        :mode "meson.build")

      ;; undo-tree
      (use-package undo-tree
        :init
        (unless (file-directory-p "~/drafts/undotrees")
          (make-directory "~/drafts/undotrees" t))
        (setq undo-tree-history-directory-alist '(("." . "~/drafts/undotrees"))
              undo-tree-auto-save-history t)
        :hook
        ((fundamental-mode . undo-tree-mode)
         (prog-mode . undo-tree-mode)
         (text-mode . undo-tree-mode))
        :custom
        (evil-undo-system 'undo-tree))


      (use-package dtrt-indent
        :config
        (dtrt-indent-mode 1)
        (add-hook 'dtrt-indent-adapt-hook
          (lambda ()
            (setq-local evil-shift-width dtrt-indent-original-indent))))

      (setq auto-save-file-name-transforms
        '((".*" "~/drafts/emacs/\\1" t)))
      (setq backup-directory-alist '(("." . "~/drafts/emacs/backups")))
      (setq lock-file-name-transforms '(("\\`/.*/\\([^/]+\\)\\'" "~/drafts/emacs/locks/\\1" t)))

      (use-package direnv
        :config
        (direnv-mode 1)
        (defun my-direnv-update-after-cd (&rest _)
          "Update direnv environment after changing directories."
          (direnv-update-environment)))

      (advice-add 'cd :after #'my-direnv-update-after-cd)

      ;; Evil mode
      (use-package evil
        :config
        (evil-mode 1)
        :custom
        (evil-want-keybinding nil))

      (use-package evil-collection
        :after evil
        :config
        (evil-collection-init))

      ;; Keep Ediff control panel in the current frame, at the bottom, small
      (setq ediff-window-setup-function 'ediff-setup-windows-plain)

      (add-hook 'after-change-major-mode-hook
              (lambda ()
                  (when (eq major-mode 'fundamental-mode)
                  (run-hooks 'fundamental-mode-hook))))

      ;; Make C do "normal" TAB after the first tabstop
      ;; (setq-default c-tab-always-indent nil)

      (use-package flycheck
        :hook ((after-init-hook . global-flycheck-mode)))

      ;; Claude Code (CLI) integration
      (require 'subr-x)
      (require 'project)

      (defun czar/claude-code ()
        "Run `claude-code` in an `ansi-term` buffer, rooted at the current project if any."
        (interactive)
        (let* ((exe (or (executable-find "claude-code")
                        (user-error "claude-code not found in PATH")))
               (default-directory
                 (or (when-let ((proj (project-current nil)))
                       (project-root proj))
                     default-directory)))
          (ansi-term exe "claude-code")))

      (global-set-key (kbd "C-c c") #'czar/claude-code)
    '';
  };

  # Core CLI tools
  home.packages = with pkgs; [
    direnv
  ];

}
