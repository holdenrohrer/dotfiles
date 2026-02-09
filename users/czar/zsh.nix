{ config, pkgs, inputs, outputs, sharedConfig, ... }:
{
  programs.zsh = {
    enable = true;

    shellAliases = {
      vim = "$VISUAL";
      vi = "$VISUAL";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
}
