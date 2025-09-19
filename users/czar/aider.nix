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
        :custom
        (comint-prompt-read-only t)
        (aidermacs-default-chat-mode 'architect))
    '';
  };

  # CLI tools required for Aider to work well
  home.packages = with pkgs; [
    aider-chat
    git
    gnupg
  ];

  # Aider CLI configuration
  home.file.".aider.conf.yml" = {
    text = ''
      lint-cmd: "${pkgs.python3Packages.flake8}/bin/flake8"
    '';
  };
}
