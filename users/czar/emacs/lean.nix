{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    elan
  ];

  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      #lean4-mode
    ];

    extraConfig = ''
    '';
  };
}
