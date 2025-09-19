{ config, pkgs, ... }:

{
  # Dark mode

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
 
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
    };
  };
 
  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style = {
      name = "adwaita-dark";
      #package = pkgs.adwaita-qt;
    };
  };
}
