{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  imports = [
    ./sudoedit.nix
    ./gptel.nix
    ./haskell.nix
    ./lean.nix
  ];

  # Keep an Emacs server running so emacsclient always has a socket.
  services.emacs.enable = true;

  # Emacs configuration
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;

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
      eat
      (melpaBuild {
        pname = "claude-code-ide";
        version = "0.0.1";
        src = pkgs.applyPatches {
          name = "claude-code-ide-patched";
          src = inputs.claude-code-ide;
          patches = [ ./claude-code-ide-fix-allowed-tools.patch ];
        };
        recipe = pkgs.writeText "recipe" ''
          (claude-code-ide :repo "manzaltu/claude-code-ide.el" :fetcher github)
        '';
        packageRequires = [ transient websocket web-server ];
      })
    ];

    extraConfig = ''
      ;; Avoid (require) and stick to (use-package)

      ;; Basic dark theme
      (load-theme 'wombat t)

      ;; Gentler UI: remove chrome (scroll bars, menu/tool bars, tab bar).
      (when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
      (when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
      (when (fboundp 'menu-bar-mode) (menu-bar-mode -1))
      (when (fboundp 'tab-bar-mode) (tab-bar-mode -1))

      ;; Match foot's alpha=0.7 (70% opaque background).
      ;; (Wayland-friendly in recent Emacs via alpha-background.)
      (add-to-list 'default-frame-alist '(alpha-background . 70))
      (defun czar/apply-frame-transparency (frame)
      (when (display-graphic-p frame)
          (set-frame-parameter frame 'alpha-background 70)))

      (add-hook 'after-make-frame-functions #'czar/apply-frame-transparency)

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

      (use-package eat
        :config
        (define-key eat-char-mode-map (kbd "C-y") #'eat-yank)
        (define-key eat-line-mode-map (kbd "C-y") #'eat-yank))

      (defun czar/eat-new ()
        "Open a new Eat shell instead of reusing the current terminal buffer."
        (interactive)
        ;; Eat supports creating a new terminal when invoked with a prefix arg.
        (eat nil t))

      (use-package claude-code-ide
        :bind ("C-c C-'" . claude-code-ide-menu)
        :custom
        (claude-code-ide-terminal-backend 'eat)
        (claude-code-ide-debug t)
        (claude-code-ide-cli-debug t)
        (claude-code-ide-mcp-allowed-tools 'auto)
        :config
        (claude-code-ide-emacs-tools-setup)
        (defun czar/claude-code-hide-nobreak-space (buffer &rest _)
          "Hide non-breaking space glyph in Claude Code terminal BUFFER."
          (with-current-buffer (car buffer)
            (setq-local nobreak-char-display nil))
          buffer)
        (advice-add 'claude-code-ide--create-terminal-session
                    :filter-return #'czar/claude-code-hide-nobreak-space))
    '';
  };

  # Core CLI tools
  home.packages = with pkgs; [
    direnv
  ];

}
