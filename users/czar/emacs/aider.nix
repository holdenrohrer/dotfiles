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
        (setenv "AIDER_WEAK_MODEL" "openrouter/openai/gpt-4o-mini")
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
    '';
  };
}
