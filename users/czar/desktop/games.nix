# Games packages — imported only on the personal machine
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    hyperrogue
    prismlauncher
    lutris
  ];
}
