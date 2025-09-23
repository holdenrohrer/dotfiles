{ config, pkgs, ... }:

{
  imports = [ ./aider.nix ];

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
    ];

    extraConfig = ''
      ;; Basic dark theme
      (load-theme 'wombat t)

      ;; Indent with spaces, default to 4
      (setq-default indent-tabs-mode nil)
      (setq-default tab-width 4)
      (setq indent-line-function 'indent-relative)

      (add-hook 'before-save-hook 'whitespace-cleanup)

      ; Fold text at word boundaries
      ; And use the visual-fill-column package to
      (use-package visual-fill-column
        :hook
        ((fundamental-mode . visual-line-mode))
        :config
        (setq-default fill-column 100)
        (global-visual-fill-column-mode 1)
        (global-visual-line-mode 1))

      (use-package nix-mode
        :mode "\\.nix\\'")

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

      (use-package sudo-edit
        :hook
        (find-file . sudo-reopen-if-read-only)
        :config
        (defun sudo-reopen-if-read-only ()
          "If file is read-only, reopen it with sudo."
          (when (and buffer-file-name
                     (not (file-writable-p buffer-file-name)))
            (let ((pos (point)))
              (sudo-edit)
              (goto-char pos)))))

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
    '';
  };

  # Core CLI tools
  home.packages = with pkgs; [
    direnv
  ];

}
