{ config, pkgs, inputs, outputs, sharedConfig, ... }:

{
  # Emacs packages and configuration for gptel, mirroring Aider's API key/model choices.
  programs.emacs = {
    extraPackages = epkgs: with epkgs;
      let
        gptel = melpaBuild {
          pname = "gptel";
          version = "20260530";
          src = inputs.gptel-src;
          # Without explicit deps, melpaBuild byte-compiles against Emacs's
          # builtin transient (0.7.x), which lacks the :environment slot that
          # current gptel uses — so it must pull the package-set transient.
          packageRequires = with epkgs; [ transient compat ];
        };

        gptelMagit = melpaBuild {
          pname = "gptel-magit";
          version = "20251010";
          src = inputs.gptel-magit-src;
          packageRequires = [ gptel magit ];
        };
      in [
        gptel
        gptelMagit
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
                :models '(openai/gpt-5
                            anthropic/claude-sonnet-4.5
                            moonshotai/kimi-k2-0905)))

        ;; Set GPT-5 as default model
        (setq gptel-model 'openai/gpt-5)

        (setq gptel-default-mode 'org-mode)

        ;; Codex / ChatGPT subscription backend via gptel's native OAuth.
        ;; No API key: talks to chatgpt.com/backend-api/codex/responses using
        ;; the sub. One-time device-flow login: M-x gptel-openai-oauth-login
        ;; (token cached under <user-emacs-directory>/.cache/gptel-openai/).
        (require 'gptel-openai-oauth)
        (gptel-make-openai-oauth "Codex-sub"
          :models '(gpt-5.5 gpt-5.4 gpt-5.4-mini gpt-5.3-codex))

        ;; Groq Kimi2 preset - forces Groq provider
        (gptel-make-openai "Groq Kimi2"
            :host "openrouter.ai"
            :endpoint "/api/v1/chat/completions"
            :stream t
            :key (lambda () (password-store-get-field "openrouter" "apikey"))
            :models '("moonshotai/kimi-k2-0905")
            :request-params '(("provider" . (("order" . ["Groq"]))))))

      (use-package gptel-magit
        :hook (magit-mode . gptel-magit-install)
        :config
        ;; Fix: gptel calls the response callback with (reasoning . "...") cons
        ;; cells for models that return extended thinking. gptel-magit assumes
        ;; the response is always a string, causing "Wrong type argument:
        ;; char-or-string-p" when it tries to (insert response).
        ;; Override to add a stringp guard in the inner gptel-request callback.
        (define-advice gptel-magit--generate (:override (callback) filter-reasoning)
          (let ((diff (magit-git-output "diff" "--cached")))
            (gptel-magit--request diff
              :system gptel-magit-commit-prompt
              :context nil
              :callback (lambda (response _info)
                          (when (stringp response)
                            (let ((msg (gptel-magit--format-commit-message response)))
                              (funcall callback msg))))))))

    '';
  };
}
