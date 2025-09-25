{ config, pkgs, ... }:

{
  # Emacs packages and configuration specifically for Aider/AiderMacs
  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      aidermacs
      password-store
    ];

    extraConfig = ''
      (use-package aidermacs
        :bind (("C-c a" . aidermacs-transient-menu))
        :config
        (setenv "OPENROUTER_API_KEY" (password-store-get-field "openrouter" "apikey"))
        (setenv "AIDER_EDIT_FORMAT" "diff")
        (setenv "AIDER_MODEL" "openrouter/openai/gpt-5")
        (setenv "AIDER_WEAK_MODEL" "openrouter/openai/gpt-5-nano")
        :custom
        (comint-prompt-read-only t)
        (aidermacs-program "${pkgs.aider-chat}/bin/aider")
        (aidermacs-default-chat-mode 'architect))
    '';
  };

  # Aider CLI configuration
  home.file.".aider.conf.yml" = {
    text = ''
      lint-cmd: "${pkgs.python3Packages.flake8}/bin/flake8"
      auto-lint: false
      model-settings-file: kimi-k2-groq.json
    '';
  };

  home.file.".aider/kimi-k2-groq.json" = {
    text = ''
      {
        "moonshotai/kimi-k2-0905": {
          "max_context_tokens": 256000,
          "max_output_tokens": 8192,
          "input_cost_per_token": 0.00000014,
          "output_cost_per_token": 0.00000249,
          "litellm_provider": "openrouter",
          "provider": "groq",
          "edit_format": "diff"
        }
      }
    '';
  };
}
