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
      gptel
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
        (defvar sudo-reopen--in-progress nil
          "Non-nil while reopening a buffer via sudo to prevent recursion.")
        (defun sudo-reopen-if-read-only ()
          "If visiting a local, non-sudo path that isn't writable, try reopening via sudo.
Uses EAFP: attempt sudo-edit unconditionally for unreadable/unwritable targets and
falls back gracefully if root cannot open or the path remains read-only.
Prevents recursion and skips TRAMP buffers."
          (unless sudo-reopen--in-progress
            (when (and buffer-file-name
                       (not (file-remote-p buffer-file-name))
                       (not (string-prefix-p "/sudo:" buffer-file-name))
                       (not (file-writable-p buffer-file-name)))
              (let ((pos (point))
                    (sudo-reopen--in-progress t))
                (condition-case _
                    (progn
                      (sudo-edit)
                      ;; After sudo-edit, only keep sudo buffer if it improved perms.
                      (when (and (string-prefix-p "/sudo:" (or buffer-file-name ""))
                                 (not (file-writable-p buffer-file-name)))
                        ;; Root doesn't help (still not writable), revert to original path.
                        ;; This preserves EAFP while failing back gracefully.
                        (revert-buffer t t)))
                  (error
                   ;; If sudo-edit fails (e.g., cannot stat in 0700 dir or auth issues),
                   ;; silently keep the original buffer.
                   nil))
                (goto-char pos))))))

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
        (defvar my-global-default-directory default-directory
          "Global default directory that buffers should use unless manually changed with :cd.")
        (add-hook 'find-file-hook
                  (lambda ()
                    (setq default-directory my-global-default-directory)))
        (defun my-direnv-update-after-cd (&rest _)
          "Update direnv environment after changing directories."
          (direnv-update-environment)
          (setq my-global-default-directory default-directory)))


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
    '';
  };

  # Core CLI tools
  home.packages = with pkgs; [
    direnv
  ];

}
