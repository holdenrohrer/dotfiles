{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    ghc
    stack
    ormolu
    hlint
    haskell-language-server
  ];

  home.file.".stack/config.yaml".text = ''
    resolver: lts-24.11
  '';

  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      haskell-mode
    ];
  };
}
