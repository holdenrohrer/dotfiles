{ config, pkgs, inputs, outputs, sharedConfig, ... }:
{
  programs.zsh = {
    enable = true;

    shellAliases = {
      vim = "emacsclient -t -a emacs";
      vi = "emacsclient -t -a emacs";
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
}
