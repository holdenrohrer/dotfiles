;; Avoid (require) and stick to (use-package)

;; Open ticket.org by default on work machine
(when (string= (system-name) "work")
  (setq initial-buffer-choice "~/projects/ticket.org"))

;; Org-mode
(setq org-agenda-files '("~/projects/ticket.org"))
(global-set-key (kbd "C-c a") #'org-agenda)

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

;; Default directory should be project root when in a project
(defun my-set-default-directory-to-project-root ()
  "Set default-directory to project root if in a project."
  (when-let ((project (project-current))
             (root (project-root project)))
    (setq-local default-directory root)))

(add-hook 'find-file-hook #'my-set-default-directory-to-project-root)

;; Enable emacsclient
(require 'server)
(unless (server-running-p)
  (server-start))

;; Indent with spaces, default to 4
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq indent-line-function 'indent-relative)

(add-hook 'before-save-hook 'whitespace-cleanup)

(defun czar/toggle-aggressive-formatting ()
  "Toggle aggressive formatting (whitespace-cleanup on save + aggressive-indent)."
  (interactive)
  (if (memq 'whitespace-cleanup (default-value 'before-save-hook))
      (progn
        (remove-hook 'before-save-hook 'whitespace-cleanup)
        (global-aggressive-indent-mode -1)
        (message "Aggressive formatting OFF"))
    (add-hook 'before-save-hook 'whitespace-cleanup)
    (global-aggressive-indent-mode 1)
    (message "Aggressive formatting ON")))

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

;; Tree-sitter modes for TypeScript/TSX
(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))

;; Apex (.cls, .trigger) — use java-ts-mode with extra keywords
(add-to-list 'auto-mode-alist '("\\.cls\\'" . java-ts-mode))
(add-to-list 'auto-mode-alist '("\\.trigger\\'" . java-ts-mode))
(defvar czar/apex-extra-keywords
  '("trigger" "testMethod" "webService" "global" "with sharing"
    "without sharing" "inherited sharing"))
(add-hook 'java-ts-mode-hook
          (lambda ()
            (when (and buffer-file-name
                       (string-match-p "\\.\\(cls\\|trigger\\)\\'" buffer-file-name))
              (font-lock-add-keywords
               nil
               `((,(regexp-opt czar/apex-extra-keywords 'symbols)
                  . font-lock-keyword-face))))))

;; Go
(add-to-list 'auto-mode-alist '("\\.go\\'" . go-ts-mode))
(add-to-list 'auto-mode-alist '("go\\.mod\\'" . go-mod-ts-mode))
(add-hook 'go-ts-mode-hook
          (lambda ()
            (setq-local indent-tabs-mode t)
            (setq-local tab-width 4)
            (add-hook 'before-save-hook
                      (lambda ()
                        (when (eglot-managed-p)
                          (ignore-errors
                            (eglot-code-action-organize-imports (point-min) (point-max)))
                          (eglot-format-buffer)))
                      nil t)))

;; Eglot (built-in LSP client)
(use-package eglot
  :hook (prog-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs '(nix-mode . ("nixd")))
  ;; Use ormolu for Haskell formatting
  (setq-default eglot-workspace-configuration
                '(:haskell (:formattingProvider "ormolu")))
  (setq eglot-autoshutdown t))

;; undo-tree
(use-package undo-tree
  :init
  (unless (file-directory-p "~/drafts/undotrees")
    (make-directory "~/drafts/undotrees" t))
  (setq undo-tree-history-directory-alist '(("." . "~/drafts/undotrees"))
        undo-tree-auto-save-history t)
  :config
  (global-undo-tree-mode 1)
  ;:hook
  ;((fundamental-mode . undo-tree-mode)
  ; (prog-mode . undo-tree-mode)
  ; (text-mode . undo-tree-mode))
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

(use-package envrc
  :hook (after-init . envrc-global-mode))

;; Evil mode
(use-package evil
  :config
  (evil-mode 1)
  :custom
  (evil-want-keybinding nil))

;; Fix Evil's o/O to use RET, which modes handle more reliably than
;; indent-according-to-mode. See: github.com/haskell/haskell-mode/issues/1265
(defun czar/evil-open-below (count)
  "Simulate evil's o using 'A RET'."
  (interactive "p")
  (setq unread-command-events (listify-key-sequence (kbd "RET")))
  (evil-append-line count))

(defun czar/evil-open-above (count)
  "Simulate evil's O by going up one line then doing o."
  (interactive "p")
  (if (= (line-number-at-pos) 1)
      (progn
        (beginning-of-line)
        (open-line count)
        (evil-insert-state 1))
    (forward-line -1)
    (setq unread-command-events (listify-key-sequence (kbd "RET")))
    (evil-append-line count)))

(define-key evil-normal-state-map "o" #'czar/evil-open-below)
(define-key evil-normal-state-map "O" #'czar/evil-open-above)

(use-package evil-collection
  :after (evil magit)
  :config
  (evil-collection-init))

;; Keep Ediff control panel in the current frame, at the bottom, small
(setq ediff-window-setup-function 'ediff-setup-windows-plain)

(add-hook 'after-change-major-mode-hook
        (lambda ()
            (when (eq major-mode 'fundamental-mode)
            (run-hooks 'fundamental-mode-hook))))


(use-package flycheck
  :hook ((after-init-hook . global-flycheck-mode))
  :config
  (add-hook 'eglot-managed-mode-hook
            (lambda () (when (eglot-managed-p) (flycheck-mode -1)))))

(use-package eat
  :config
  (defun czar/eat-kill-buffer-and-window (process)
    "Kill eat buffer and close window/frame when PROCESS exits."
    ;; explicit check to ensure we don't act on a deleted buffer
    (when-let* ((buf (process-buffer process))
                ((buffer-live-p buf))
                ;; Pass t to find the window in any frame
                (win (get-buffer-window buf t)))
      (with-selected-window win
        ;; quit-window with KILL=t kills the buffer.
        ;; If quit-restore is set correctly, this will also delete the frame.
        (quit-window t win))))

  (add-hook 'eat-exit-hook #'czar/eat-kill-buffer-and-window))

(defun czar/eat-new ()
  "Open a new Eat terminal in a dedicated frame."
  (interactive)
  ;; 1. Create the frame first
  (let ((frame (selected-frame)))
    ;; 2. Select the frame immediately so `eat` sees a valid window/geometry
    (select-frame frame)
    (eat nil t)
    ;; 3. Start eat. This switches the new window to the *eat* buffer.
    ;; Note: If you prefer your specific arguments, use (eat nil t) but
    ;; ensure you switch to the buffer manually if it doesn't happen auto.
    ;; 4. Set the quit-restore parameter on the selected window.
    ;; Structure: (METHOD OBUFFER OWINDOW THIS-BUFFER)
    ;; We use `list` to ensure `(current-buffer)` is evaluated to the actual object.
    (let ((win (selected-window)))
      (set-window-prev-buffers win nil)
      (set-window-parameter win 'quit-restore
                            (list 'frame 'frame nil (window-buffer win))))))

(defun czar/eat-restart ()
  "Kill the current Eat terminal and open a fresh one in the same window."
  (interactive)
  (unless (derived-mode-p 'eat-mode)
    (user-error "Not in an Eat terminal"))
  (let ((dir default-directory))
    (remove-hook 'eat-exit-hook #'czar/eat-kill-buffer-and-window)
    (when-let ((proc (get-buffer-process (current-buffer))))
      (set-process-query-on-exit-flag proc nil))
    (unwind-protect
        (kill-buffer (current-buffer))
      (add-hook 'eat-exit-hook #'czar/eat-kill-buffer-and-window))
    (let ((default-directory dir))
      (eat nil t))))

(global-set-key (kbd "C-c t") #'czar/eat-new)
(global-set-key (kbd "C-c u") #'czar/eat-restart)

;; ========================================================================
;; Git Worktrees - Default to ~/drafts/emacs/
;; ========================================================================
;; Consistent with auto-save (line 119) and undo-tree (line 99) locations

(use-package magit
  :config
  ;; Ensure ~/drafts/emacs/ directory exists
  (unless (file-directory-p "~/drafts/emacs/worktrees")
    (make-directory "~/drafts/emacs/worktrees/" t))

  ;; Default offsite worktree location
  (defun czar/magit-worktree-read-directory-offsite (prompt branch)
    "Read worktree directory with ~/drafts/emacs/worktrees/ as default.
PROMPT is displayed to user. BRANCH is the branch name for the new worktree."
    (let* ((repo-name (file-name-nondirectory
                       (directory-file-name (magit-toplevel))))
           (branch-name (if branch
                            (replace-regexp-in-string "/" "-" branch)
                          "new"))
           (default-dir (expand-file-name
                         (concat "~/drafts/emacs/worktrees/" repo-name "-" branch-name))))
      (read-directory-name prompt default-dir default-dir)))

  (setq magit-read-worktree-directory-function #'czar/magit-worktree-read-directory-offsite)

  ;; Show worktrees in magit-status buffer
  (require 'magit-worktree)
  (magit-add-section-hook 'magit-status-sections-hook
                          'magit-insert-worktrees
                          'magit-insert-stashes
                          'append))

(use-package claude-code-ide
  :bind ("C-c C-'" . claude-code-ide-menu)
  :custom
  (claude-code-ide-terminal-backend 'eat)
  (claude-code-ide-mcp-allowed-tools 'auto)
  (claude-code-ide-cli-extra-flags "--dangerously-skip-permissions")
  (claude-code-ide-no-flicker t)
  :config
  (claude-code-ide-emacs-tools-setup)
  (defun czar/claude-code-hide-nobreak-space (buffer &rest _)
    "Hide non-breaking space glyph in Claude Code terminal BUFFER."
    (with-current-buffer (car buffer)
      (setq-local nobreak-char-display nil))
    buffer)
  (advice-add 'claude-code-ide--create-terminal-session
              :filter-return #'czar/claude-code-hide-nobreak-space)

  ;; Fix: ediff opens in wrong frame
  ;; When Claude Code triggers openDiff, switch to the frame where
  ;; Claude Code is running before opening the diff.
  (defun czar/claude-code-switch-to-claude-frame (session)
    "Switch to the frame containing the Claude Code buffer for SESSION."
    (when-let* ((project-dir (claude-code-ide-mcp-session-project-dir session))
                (claude-buffer-name (claude-code-ide--get-buffer-name project-dir))
                (claude-buffer (get-buffer claude-buffer-name)))
      (let ((target-frame
             (catch 'found
               (dolist (frame (frame-list))
                 (dolist (window (window-list frame))
                   (when (eq (window-buffer window) claude-buffer)
                     (throw 'found frame))))
               ;; Fallback: find frame with project files
               (dolist (frame (frame-list))
                 (dolist (window (window-list frame))
                   (when-let ((buf (window-buffer window))
                              (file (buffer-file-name buf)))
                     (when (string-prefix-p (expand-file-name project-dir)
                                            (expand-file-name file))
                       (throw 'found frame)))))
               nil)))
        (when target-frame
          (select-frame-set-input-focus target-frame)
          target-frame))))

  (defun czar/claude-code-open-diff-frame-aware (orig-fun arguments)
    "Advice to switch to Claude frame before opening diff."
    (let* ((old-file-path (alist-get 'old_file_path arguments))
           (session (or (claude-code-ide-mcp--find-session-for-file old-file-path)
                        (claude-code-ide-mcp--get-current-session))))
      (when session
        (czar/claude-code-switch-to-claude-frame session))
      (funcall orig-fun arguments)))

  (advice-add 'claude-code-ide-mcp-handle-open-diff
              :around #'czar/claude-code-open-diff-frame-aware)

  ;; Fix: Claude Code doesn't detect window resizes from WM/Emacs frame changes
  (defun czar/claude-code-handle-window-resize (frame)
    "Handle window size changes for Claude Code buffers in FRAME."
    (dolist (window (window-list frame))
      (let ((buffer (window-buffer window)))
        (when (and buffer
                   (buffer-live-p buffer)
                   (string-prefix-p "*claude-code[" (buffer-name buffer)))
          (with-current-buffer buffer
            (when-let ((proc (get-buffer-process buffer)))
              (let ((height (window-body-height window))
                    (width (window-body-width window)))
                (set-window-parameter window 'claude-code-ide-cached-width width)
                (set-process-window-size proc height width))))))))

  (add-hook 'window-size-change-functions #'czar/claude-code-handle-window-resize))

;; Perspective - workspace management
(use-package perspective
  :bind (("C-x C-b" . persp-list-buffers)
         ("C-x b" . persp-switch-to-buffer*)
         ("C-x k" . persp-kill-buffer*))
  :custom
  (persp-mode-prefix-key (kbd "C-c M-p"))
  :init
  (persp-mode))

  ;; Aggressively indent everything
  (use-package aggressive-indent
    :config
    (add-to-list 'aggressive-indent-excluded-modes 'go-ts-mode)
    (global-aggressive-indent-mode 1))

;; ein: skip /login when server has no auth
;; jupyter_server 2.0+ removes the /login endpoint when no token is set,
;; causing ein:login to fail with 404. Convert nil (unknown auth) to ""
;; (no auth) so ein skips login and goes straight to the notebook list.
(with-eval-after-load 'ein-notebooklist
  (defun czar/ein-no-auth-fallback (result)
    (or result ""))
  (advice-add 'ein:notebooklist-token-or-password
              :filter-return #'czar/ein-no-auth-fallback))
