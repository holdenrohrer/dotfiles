{ config, pkgs, ... }:

{
  programs.emacs = {
    extraConfig = ''
      (use-package sudo-edit
        :hook
        (find-file . sudo-reopen-if-read-only)
        :config
        (defvar sudo-reopen--in-progress nil
          "Non-nil while reopening a buffer via sudo to prevent recursion.")

        ;; Shared helpers to keep logic DRY
        (defun sudo-reopen--should-sudo-p (filename)
          "Return non-nil if FILENAME should be considered for sudo reopening."
          (and filename
               (not sudo-reopen--in-progress)
               (not (file-remote-p filename))
               (not (string-prefix-p "/sudo:" filename))))

        (defun sudo-reopen--sudo-filename (filename)
          "Return the sudo TRAMP variant of FILENAME, or nil if unavailable."
          (when (and (sudo-reopen--should-sudo-p filename)
                     (fboundp 'sudo-edit-filename))
            (sudo-edit-filename filename)))

        (defun sudo-reopen--permission-denied-p (err)
          "Return non-nil if file-error ERR indicates a permission problem."
          (and (eq (car err) 'file-error)
               (let ((msg (error-message-string err)))
                 (or (string-match-p "[Pp]ermission denied" msg)
                     (string-match-p "\\bEACCES\\b" msg)
                     (string-match-p "\\bEPERM\\b" msg)))))

        (defun sudo-reopen-if-read-only ()
          "If visiting a local, non-sudo path that isn't writable, try reopening via sudo.
Uses EAFP and falls back gracefully if root cannot open or does not improve permissions.
Prevents recursion and skips TRAMP buffers."
          (let ((filename buffer-file-name))
            (when (and (sudo-reopen--should-sudo-p filename)
                       (not (file-writable-p filename)))
              (let ((pos (point)))
                (condition-case _
                    (let* ((sudo-reopen--in-progress t)
                           (sudo-file (sudo-reopen--sudo-filename filename)))
                      (when sudo-file
                        (find-alternate-file sudo-file)
                        ;; After sudo-open, if permissions didn't improve, switch back.
                        (when (and (string-prefix-p "/sudo:" (or buffer-file-name ""))
                                   (not (file-writable-p buffer-file-name)))
                          (find-alternate-file filename))))
                  (error nil))
                (goto-char pos)))))

        (defun sudo-reopen--try-sudo-on-permission-denied (orig-fun filename &rest args)
          "Around advice for `find-file-noselect` to try sudo on permission denied.
If the original call errors with a permission issue, retry opening the same FILENAME
via sudo (TRAMP). Falls back to the original error if sudo also fails. Skips remote and
already-sudo paths, and prevents recursion. Uses shared helpers to stay DRY."
          (if (not (sudo-reopen--should-sudo-p filename))
              (apply orig-fun filename args)
            (condition-case err
                (apply orig-fun filename args)
              (file-error
               (if (sudo-reopen--permission-denied-p err)
                   (let ((sudo-file (sudo-reopen--sudo-filename filename)))
                     (if sudo-file
                         (let ((sudo-reopen--in-progress t))
                           (apply orig-fun sudo-file args))
                       (signal (car err) (cdr err))))
                 (signal (car err) (cdr err)))))))

        (advice-add 'find-file-noselect :around #'sudo-reopen--try-sudo-on-permission-denied))
    '';
  };
}
