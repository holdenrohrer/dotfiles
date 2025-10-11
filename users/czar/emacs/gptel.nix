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
            rev = "main";
            sha256 = "sha256-Ngwocb5k+d8FPQNoWNIxFxImnGqPaTzKz0YX8O+7ugU=";
          };
          recipe = pkgs.writeText "macher-recipe" ''
            (macher :repo "kmontag/macher" :fetcher github :branch "main" :files ("*.el"))
          '';
          packageRequires = [ gptel ];
        };
      in [
        gptel
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

      (use-package macher
        :config
        ;; Use org UI and install presets into gptel
        (setq macher-action-buffer-ui 'org)
        (macher-install))
    '';
  };
}
