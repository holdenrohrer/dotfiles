{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    ocaml
    dune_3
    ocamlPackages.ocaml-lsp
    ocamlPackages.ocamlformat
    ocamlPackages.utop
  ];

  programs.emacs = {
    extraPackages = epkgs: with epkgs; [
      tuareg
      utop
    ];
  };
}
