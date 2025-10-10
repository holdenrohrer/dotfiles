{ config, pkgs, ... }:

{
  # Emacs packages and configuration for gptel, mirroring Aider's API key/model choices.
  programs.emacs = {
    extraPackages = epkgs: with epkgs;
      let
        gptel = melpaBuild {
          pname = "gptel";
          version = "unstable-2025-10-10";
          src = pkgs.fetchFromGitHub {
            owner = "karthink";
            repo = "gptel";
            rev = "main";
            sha256 = pkgs.lib.fakeSha256;
          };
          recipe = pkgs.writeText "gptel-recipe" ''
            (gptel :repo "karthink/gptel" :fetcher github :branch "main" :files ("*.el"))
          '';
        };
      in [
        gptel
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
    '';
  };
}
