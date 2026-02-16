{ config, pkgs, inputs, outputs, sharedConfig, ... }:
{
  programs.zsh = {
    enable = true;

    shellAliases = {
      vim = "emacsclient -r -a emacs";
      vi = "emacsclient -r -a emacs";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
}
