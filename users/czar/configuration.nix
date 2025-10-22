{ config, pkgs, inputs, outputs, sharedConfig, ... }:
{
  imports = [
    ./emacs/configuration.nix
    ./desktop/configuration.nix
    ./zsh.nix
  ];

  home = {
    file.passff-host-workaround = {
      target = "${config.home.homeDirectory}/.mozilla/native-messaging-hosts/passff.json";
      source = "${pkgs.passff-host}/share/passff-host/passff.json";
    };
    stateVersion = "25.05";
    username = "czar";
    homeDirectory = "/home/czar";
    packages = with pkgs; [
      git
      gnupg
      imagemagickBig
      nmap
    ];
  };

  # Fixing the XDG Directory Structure
  xdg.userDirs = {
    enable = true;
    download = "$HOME/dl";
    # Disable the other directories because I don't use them.
    desktop = "";
    documents = "";
    music = "";
    pictures = "";
    videos = "";
  };

  home.file.".profile" = {
    text = ''
      export MAKEFLAGS="-j8"
      alias julia="QT_QPA_PLATFORM=xcb julia"
      alias pb="nc hrhr.dev 9999"

      export MOZ_ENABLE_WAYLAND=1
      export XDG_CURRENT_DESKTOP=sway
    '';
  };
}
