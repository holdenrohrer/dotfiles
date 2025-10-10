{ config, pkgs, ... }:

{
  # Emacs packages and configuration for gptel, mirroring Aider's API key/model choices.
  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      gptel
      password-store
    ];

    extraConfig = ''
      (use-package gptel
        :commands (gptel gptel-send gptel-menu)
        :config
        ;; Get OpenRouter API key from password-store.
        (defun my-gptel--openrouter-key ()
          (password-store-get-field "openrouter" "apikey")))


        ;; Use OpenRouter backend and mirror Aider's model choices.
        ;; Default model: openrouter/openai/gpt-5
        ;; Quick/weak model: openrouter/openai/gpt-5-nano
        (setq gptel-backend
              (gptel-make-openai "OpenRouter"
                :host "openrouter.ai/api"
                :endpoint "/v1/chat/completions"
                :key (my-gptel--openrouter-key)))

        (setq gptel-model "openrouter/openai/gpt-5")

        ;; Presets that reflect the roles used in Aider/AiderMacs
        (gptel-defpreset architect
          :description "Architect: concise, minimal-diff responses (mirrors Aider's architect mode)."
          :system "You are an expert software developer. Provide concise, actionable guidance and prefer responding with minimal unified diffs when changing code."
          :model "openrouter/openai/gpt-5")

        (gptel-defpreset quick
          :description "Quick: fast, terse responses using the weak model."
          :system "Be terse and fast. Prefer brief patches and one-liners."
          :model "openrouter/openai/gpt-5-nano"))
    '';
  };
}
