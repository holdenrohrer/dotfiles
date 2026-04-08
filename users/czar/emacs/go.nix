{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    go
    gopls
    gotools  # goimports, etc.
    delve    # debugger
  ];

  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      go-mode
    ];
  };
}
