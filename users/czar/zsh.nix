{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    # Make zsh the login shell via Home Manager (requires HM as a NixOS module, which your flake provides)
    loginShell = true;

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
  };
}
