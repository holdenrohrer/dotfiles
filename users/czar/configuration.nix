{ config, lib, pkgs, inputs, outputs, sharedConfig, ... }:
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
    sessionVariables = {
      EDITOR = "emacsclient -t -a emacs";
      VISUAL = "emacsclient -c -a emacs";
      TERMINAL = "emacsclient -c -a emacs";
    };
    packages = with pkgs; [
      git
      gnupg
      imagemagickBig
      nmap
      just
      claude-code
      texliveFull
    ];
  };

  home.activation.reloadSwayAndEmacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    log_dir="$HOME/.local/state/home-manager"
    mkdir -p "$log_dir"
    log_file="$log_dir/reload-sway-emacs.log"

    {
      echo "---- $(date -Iseconds) ----"

      # Reload Sway even when SWAYSOCK isn't exported (common during HM activation).
      if command -v swaymsg >/dev/null 2>&1; then
        uid="$(id -u)"
        sway_sock="${SWAYSOCK:-}"
        if [ -z "$sway_sock" ]; then
          sway_sock="$(ls -t "/run/user/$uid"/sway-ipc.*.sock 2>/dev/null | head -n 1 || true)"
        fi

        if [ -n "$sway_sock" ]; then
          swaymsg -s "$sway_sock" reload || true
        else
          echo "No sway IPC socket found; skipping sway reload"
        fi
      fi

      # Ensure an Emacs server exists, then reload init.
      if command -v emacsclient >/dev/null 2>&1; then
        if command -v systemctl >/dev/null 2>&1; then
          systemctl --user start emacs.service >/dev/null 2>&1 || true
        fi
        emacsclient -a false -e "(load user-init-file)" || true
      fi
    } >>"$log_file" 2>&1
  '';

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
