{ config, pkgs, ... }:

{
  # Emacs configuration
  programs.emacs = {
    enable = true;
    
    extraPackages = epkgs: with epkgs; [
      evil
      evil-collection
      magit
      transient
      aidermacs
      use-package
      password-store
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

      ; Fold text at word boundaries
      (visual-line-mode)
      ; And use the visual-fill-column package to 
      (use-package visual-fill-column
        :config
        (setq-default fill-column 100)
        (global-visual-fill-column-mode 1))

      (use-package nix-mode
        :mode "\\.nix\\'")

      ;; undo-tree
      (use-package undo-tree
        :config
        (global-undo-tree-mode)
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
        (dtrt-indent-mode 1))

      (setq auto-save-file-name-transforms
        '((".*" "~/drafts/emacs/\\1" t)))
      (setq backup-directory-alist '(("." . "~/drafts/emacs/backups")))
 
      (use-package aidermacs
        :bind (("C-c a" . aidermacs-transient-menu))
        :config
        (setenv "OPENROUTER_API_KEY" (password-store-get-field "openrouter" "apikey"))
        (setenv "AIDER_EDIT_FORMAT" "diff")
        :custom
        (aidermacs-default-chat-mode 'architect)
        (aidermacs-default-model "openrouter/openai/gpt-5")
        (comint-prompt-read-only t))
 
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
    '';
  };
 
  # Install aider-chat (the CLI tool that AiderMacs interfaces with)
  home.packages = with pkgs; [
    # Aider CLI tool
    aider-chat
    python3Packages.flake8
    
    # Git (required for aider)
    git
 
    # To let password-store do its magic
    gnupg
 
    direnv
  ];

  home.file.".aider.conf.yml" = {
    text = ''
      lint-cmd: "python: flake8"
    '';
  };
}
