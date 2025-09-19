{ config, pkgs, ... }:

let
  screenshot = pkgs.writeScriptBin "screenshot" ''
    #!${pkgs.bash}/bin/bash
    if pgrep slurp; then
      killall slurp
    else
      slurp | grim "$@"
    fi
  '';
in
{
  # GUI/desktop programs managed at the user level
  programs.firefox.enable = true;

  programs.foot = {
    enable = true;
    settings = {
      colors = {
        alpha = 0.7;
      };
    };
  };

  # Prefer Home Manager modules where available
  services.mako.enable = true;
  programs.zathura.enable = true;

  # Packages useful in the graphical (Wayland/Sway) environment
  home.packages = with pkgs; [
    grim
    wl-clipboard
    slurp
    screenshot

    hyperrogue
    feh
    anki
    prismlauncher
    wayprompt
  ];
}
