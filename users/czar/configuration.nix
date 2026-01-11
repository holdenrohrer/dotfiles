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

  # Run after the new Home Manager generation has been linked.
  #
  # Note: HM activations are executed under a script that may have `set -e`
  # enabled. We defensively disable `-e` inside this hook so a single failure
  # (e.g. no emacs server yet) doesn't abort the rest of the logging/steps.
  home.activation.reloadSwayAndEmacs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    log_dir="$HOME/.local/state/home-manager"
    mkdir -p "$log_dir"
    log_file="$log_dir/reload-sway-emacs.log"

    {
      set +e

      echo "---- $(date -Iseconds) ----"

      uid="$(id -u)"
      user="$(id -un)"

      # Ensure PATH includes the (new) HM profile.
      export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$user/bin:$PATH"

      # Best-effort environment for user services (may still be absent during activation).
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$uid}"
      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
      fi

      echo "user=$user uid=$uid"
      echo "XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-<unset>}"
      echo "DBUS_SESSION_BUS_ADDRESS=''${DBUS_SESSION_BUS_ADDRESS:-<unset>}"
      echo "PATH=$PATH"

      # --- Sway reload (socket discovery) ---
      swaymsg_path="${pkgs.sway}/bin/swaymsg"
      if [ -x "$swaymsg_path" ]; then
        sway_sock="''${SWAYSOCK:-}"
        if [ -z "$sway_sock" ]; then
          sway_sock="$(ls -t "/run/user/$uid"/sway-ipc.*.sock 2>/dev/null | head -n 1)"
        fi

        echo "swaymsg=$swaymsg_path"
        echo "SWAYSOCK=''${SWAYSOCK:-<unset>} resolved=''${sway_sock:-<none>}"

        if [ -n "$sway_sock" ]; then
          "$swaymsg_path" -s "$sway_sock" reload
          echo "sway reload rc=$?"
        else
          echo "sway reload: skipped (no socket found)"
        fi
      else
        echo "sway reload: skipped (swaymsg not executable)"
      fi

      # --- Emacs reload (ensure a server exists) ---
      emacsclient_path="${config.programs.emacs.package}/bin/emacsclient"
      emacs_path="${config.programs.emacs.package}/bin/emacs"

      if [ -x "$emacsclient_path" ]; then
        echo "emacsclient=$emacsclient_path"

        # First try: talk to an existing server.
        "$emacsclient_path" -a false -e "(progn (load user-init-file) 'ok)"
        rc="$?"
        echo "emacs reload attempt1 rc=$rc"

        # If no server exists yet, start a daemon without requiring systemd/DBus.
        if [ "$rc" -ne 0 ] && [ -x "$emacs_path" ]; then
          echo "starting emacs daemon via: $emacs_path --daemon"
          "$emacs_path" --daemon
          echo "emacs --daemon rc=$?"

          # Give the daemon a moment to create the server socket.
          sleep 0.2

          "$emacsclient_path" -a false -e "(progn (load user-init-file) 'ok)"
          echo "emacs reload attempt2 rc=$?"
        fi
      else
        echo "emacs reload: skipped (emacsclient not executable)"
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
