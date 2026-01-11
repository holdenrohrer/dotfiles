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

  # Run after the new Home Manager generation has been linked, so commands like
  # `emacsclient` are on PATH when this hook executes.
  home.activation.reloadSwayAndEmacs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    log_dir="$HOME/.local/state/home-manager"
    mkdir -p "$log_dir"
    log_file="$log_dir/reload-sway-emacs.log"

    {
      echo "---- $(date -Iseconds) ----"

      uid="$(id -u)"
      user="$(id -un)"

      # Ensure PATH includes the (new) HM profile.
      export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$user/bin:$PATH"

      # Make systemctl --user usable during activation (no GUI env by default).
      export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$uid}"
      if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      fi

      echo "user=$user uid=$uid"
      echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<unset>}"
      echo "DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-<unset>}"
      echo "PATH=$PATH"

      # Reload Sway even when SWAYSOCK isn't exported (common during HM activation).
      if swaymsg_path="$(command -v swaymsg 2>/dev/null)"; then
        sway_sock="${SWAYSOCK:-}"
        if [ -z "$sway_sock" ]; then
          sway_sock="$(ls -t "/run/user/$uid"/sway-ipc.*.sock 2>/dev/null | head -n 1 || true)"
        fi

        echo "swaymsg=$swaymsg_path"
        echo "SWAYSOCK=${SWAYSOCK:-<unset>} resolved=${sway_sock:-<none>}"

        if [ -n "$sway_sock" ]; then
          "$swaymsg_path" -s "$sway_sock" reload
          echo "sway reload: ok"
        else
          echo "sway reload: skipped (no socket found)"
        fi
      else
        echo "sway reload: skipped (swaymsg not found)"
      fi

      # Ensure an Emacs server exists, then reload init.
      if emacsclient_path="$(command -v emacsclient 2>/dev/null)"; then
        echo "emacsclient=$emacsclient_path"

        if command -v systemctl >/dev/null 2>&1; then
          systemctl --user start emacs.service || true
          echo "emacs.service active=$(systemctl --user is-active emacs.service 2>/dev/null || echo unknown)"
        else
          echo "systemctl: not found; can't start emacs.service"
        fi

        "$emacsclient_path" -a false -e "(progn (load user-init-file) 'ok)"
        echo "emacs reload: ok"
      else
        echo "emacs reload: skipped (emacsclient not found on PATH)"
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
