{ config, pkgs, ... }:

{
  # Emacs packages and configuration for gptel, mirroring Aider's API key/model choices.
  programs.emacs = {
    extraPackages = epkgs: with epkgs;
      let
        gptel = melpaBuild {
          pname = "gptel";
          version = "20251010";
          src = pkgs.fetchFromGitHub {
            owner = "karthink";
            repo = "gptel";
            rev = "d4a057e";
            sha256 = "sha256-XATIKFJ4p2xdOs8e876vdiE6KdBE2Jeb1EFPe7NaVi4=";
          };
          recipe = pkgs.writeText "gptel-recipe" ''
            (gptel :repo "karthink/gptel" :fetcher github :branch "main" :files ("*.el"))
          '';
        };

        macher = melpaBuild {
          pname = "macher";
          version = "20251010";
          src = pkgs.fetchFromGitHub {
            owner = "kmontag";
            repo = "macher";
            rev = "4fa8fbb";
            sha256 = "sha256-Ngwocb5k+d8FPQNoWNIxFxImnGqPaTzKz0YX8O+7ugU=";
          };
          recipe = pkgs.writeText "macher-recipe" ''
            (macher :repo "kmontag/macher" :fetcher github :branch "main" :files ("*.el"))
          '';
          packageRequires = [ gptel ];
        };
      in [
        gptel
        gptel-magit
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
                            "anthropic/claude-sonnet-4.5:beta"
                            "moonshotai/kimi-k2-0905")))

        ;; Set GPT-5 as default model
        (setq gptel-model "openai/gpt-5")

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
        ;; Use org UI and install presets into gptel
        (setq macher-action-buffer-ui 'org)
        (macher-install)

        ;; Minimal fix for macher read_file_in_workspace tool
        ;; Fix 1: Update tool descriptions to be clearer about optional params
        (defun my-macher--read-tools-advice (orig-fun context make-tool-function)
          "Wrap macher--read-tools to improve parameter descriptions."
          (let ((tools (funcall orig-fun context make-tool-function)))
            ;; Find and update the read_file_in_workspace tool
            (mapcar
             (lambda (tool)
               (when (equal (plist-get tool :name) "read_file_in_workspace")
                 (let ((args (plist-get tool :args)))
                   ;; Update offset description
                   (dolist (arg args)
                     (pcase (plist-get arg :name)
                       ("offset"
                        (plist-put arg :description
                                   "OPTIONAL - OMIT unless doing targeted re-read. Starting line number using 1-BASED indexing (line 1 = first line, line 50 = 50th line). DO NOT pass 0 - omit the parameter instead to read from beginning."))
                       ("limit"
                        (plist-put arg :description
                                   "OPTIONAL - OMIT unless doing targeted re-read. Maximum number of lines to read. OMIT THIS to read all remaining lines (most common). Examples: 10 reads 10 lines, 100 reads 100 lines."))
                       ("show_line_numbers"
                        (plist-put arg :description
                                   "OPTIONAL - OMIT for plain output. Set to true only if you need line numbers prefixed to each line."))))))
               tool)
             tools)))
        (advice-add 'macher--read-tools :around #'my-macher--read-tools-advice)

        ;; Fix 2: Handle limit=0 and offset=0 in the tool implementation
        (defun my-macher--tool-read-file-advice (orig-fun context path &optional offset limit show-line-numbers)
          "Treat limit=0 as nil (read all), offset=0 as 1 (start from beginning)."
          (let ((fixed-offset (if (and offset (zerop offset)) 1 offset))
                (fixed-limit (if (and limit (zerop limit)) nil limit)))
            (funcall orig-fun context path fixed-offset fixed-limit show-line-numbers)))
        (advice-add 'macher--tool-read-file :around #'my-macher--tool-read-file-advice)

        ;; Fix 3
        ;; Demand LLMs to make tool calls in parallel to save me money
        (defun my-gptel-add-parallel-tools-directive (args)
          "Add parallel tool usage directive to all gptel requests with tools."
          (when-let* ((tools (plist-get args :tools))
                      (parallel-directive "\n\nWhen you need to use multiple tools, request ALL of them in a single response. Do NOT wait for one tool's results before requesting the next tool if they can run in parallel.")
                      (current-directive (plist-get tools :directive))
                      (new-directive (concat current-directive parallel-directive)))
              (plist-put args :tools (plist-put tools :directive new-directive)))
          args)

        (advice-add 'gptel-request :filter-args #'my-gptel-add-parallel-tools-directive)

        ;; Fix 4
        ;; LLM must ask for permission before loading in particularly large files

        (defun macher-read-file-confirm-size (orig-fun &rest args)
          "Advice to confirm before reading files over 40K tokens.
        Uses gptel's confirmation system to prompt the user."
          (let* ((file (car args))
                 (file-size (when (file-exists-p file)
                              (file-attribute-size (file-attributes file))))
                 (estimated-tokens (when file-size
                                    ;; Rough estimate: 1 token ≈ 4 characters
                                    (/ file-size 4)))
                 (token-limit 40000))
            (if (and estimated-tokens (> estimated-tokens token-limit))
                (if (yes-or-no-p
                     (format "File '%s' is approximately %d tokens (%.1f MB). Include it? "
                             (file-name-nondirectory file)
                             estimated-tokens
                             (/ file-size 1024.0 1024.0)))
                    (apply orig-fun args)
                  (user-error "File inclusion cancelled by user"))
              (apply orig-fun args))))
        
        (advice-add 'macher-read-file :around #'macher-read-file-confirm-size)
      )
    '';
  };
}
