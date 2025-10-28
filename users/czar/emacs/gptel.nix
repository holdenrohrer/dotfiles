{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  # Emacs packages and configuration for gptel, mirroring Aider's API key/model choices.
  programs.emacs = {
    extraPackages = epkgs: with epkgs;
      let
        gptel = melpaBuild {
          pname = "gptel";
          version = "20251010";
          src = inputs.gptel-src;
        };

        #macher = melpaBuild {
        #  pname = "macher";
        #  version = "20251015";
        #  src = inputs.macher-src;
        #  packageRequires = [ gptel ];
        #};

        gptelMagit = melpaBuild {
          pname = "gptel-magit";
          version = "20251010";
          src = inputs.gptel-magit-src;
          packageRequires = [ gptel magit ];
        };
      in [
        gptel
        gptelMagit
        macher
        password-store
      ];

    extraConfig = ''
      (use-package gptel
        :config
        ;; Disable auth-source lookup
        (setq gptel-api-key nil)

        ;; Set OpenRouter as the default backend with GPT-5
        (setq gptel-backend
                (gptel-make-openai "OpenRouter"
                :host "openrouter.ai"
                :endpoint "/api/v1/chat/completions"
                :stream t
                :key (lambda () (password-store-get-field "openrouter" "apikey"))
                :models '("openai/gpt-5"
                            "anthropic/claude-sonnet-4.5"
                            "moonshotai/kimi-k2-0905")))

        ;; Set GPT-5 as default model
        (setq gptel-model "openai/gpt-5")

        (setq gptel-default-mode 'org-mode)

        ;; Groq Kimi2 preset - forces Groq provider
        (gptel-make-openai "Groq Kimi2"
            :host "openrouter.ai"
            :endpoint "/api/v1/chat/completions"
            :stream t
            :key (lambda () (password-store-get-field "openrouter" "apikey"))
            :models '("moonshotai/kimi-k2-0905")
            :request-params '(("provider" . (("order" . ["Groq"]))))))

      (use-package gptel-magit
        :hook (magit-mode . gptel-magit-install))

      (use-package macher
        :config
        (macher-install)

        ;; Fix 3
        ;; Demand LLMs to make tool calls in parallel to save me money
        ;(defvar my-gptel-conditional-directives nil
        ;  "List of conditional directives to add to gptel requests.
        ;Each element is a plist with :condition (a function taking ARGS)
        ;and :text (string or function returning string to append).")

        ;(defun my-gptel-add-conditional-directives (args)
        ;  "Add conditional directives to gptel-request system message."
        ;  (let* ((system (or (plist-get args :system)
        ;                     gptel--system-message
        ;                     ""))
        ;         (additions ""))

        ;    ;; Collect all applicable directive additions
        ;    (dolist (directive my-gptel-conditional-directives)
        ;      (when (funcall (plist-get directive :condition) args)
        ;        (let ((text (plist-get directive :text)))
        ;          (setq additions
        ;                (concat additions
        ;                        (if (functionp text)
        ;                            (funcall text args)
        ;                          text))))))

        ;    ;; Update system message if we have additions
        ;    (when (not (string-empty-p additions))
        ;      (plist-put args :system (concat system additions)))

        ;    args))

        ;(add-to-list 'gptel-prompt-transform-functions
        ;             #'my-gptel-add-conditional-directives
        ;             t)

        ;(defun my-gptel-parallel-tools-condition (args)
        ;  "Check if parallel tools directive should be added."
        ;  (and (bound-and-true-p gptel-use-tools)
        ;       gptel-tools
        ;       (not (null gptel-tools))))

        ;;; Define the parallel tools directive
        ;(setq my-gptel-conditional-directives
        ;      '((:condition my-gptel-parallel-tools-condition
        ;         :text "\n\nWhen you need to use multiple tools, request ALL of them in a single response. Do NOT wait for one tool's results before requesting the next tool if they can run in parallel.")))


        ;;; Fix 4
        ;;; LLM must ask for permission before loading in particularly large files

        ;(defun macher-read-file-confirm-size (orig-fun &rest args)
        ;  "Advice to confirm before reading files over 40K tokens.
        ;Uses gptel's confirmation system to prompt the user."
        ;  (let* ((file (car args))
        ;         (file-size (when (file-exists-p file)
        ;                      (file-attribute-size (file-attributes file))))
        ;         (estimated-tokens (when file-size
        ;                            ;; Rough estimate: 1 token ≈ 4 characters
        ;                            (/ file-size 4)))
        ;         (token-limit 40000))
        ;    (if (and estimated-tokens (> estimated-tokens token-limit))
        ;        (if (yes-or-no-p
        ;             (format "File '%s' is approximately %d tokens (%.1f MB). Include it? "
        ;                     (file-name-nondirectory file)
        ;                     estimated-tokens
        ;                     (/ file-size 1024.0 1024.0)))
        ;            (apply orig-fun args)
        ;          (user-error "File inclusion cancelled by user"))
        ;      (apply orig-fun args))))

        ;(advice-add 'macher-read-file :around #'macher-read-file-confirm-size)
      )
    '';
  };
}
