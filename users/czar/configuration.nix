{ config, lib, pkgs, inputs, outputs, sharedConfig, ... }:
{
  imports = [
    ./emacs/configuration.nix
    ./emacs/claude/configuration.nix
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
      EDITOR = "emacsclient -r -a emacs";
      VISUAL = "emacsclient -r -a emacs";
      TERMINAL = "emacsclient -c -a emacs";
    };
    packages = with pkgs; [
      git
      gnupg
      imagemagickBig
      pandoc
      nmap
      just
      inputs.claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
      socat # necessary for claude-code sandbox
      bubblewrap # necessary for claude-code sandbox
      nodejs # for claude-code MCP server
      texliveFull
      gh
      ripgrep
      jq
      poppler-utils
      curl
      mutt
      zbar
    ];
  };

  # Run after the new Home Manager generation has been linked.
  #
  # Note: HM activations are executed under a script that may have `set -e`
  # enabled. We defensively disable `-e` inside this hook so a single failure
  # (e.g. no emacs server yet) doesn't abort the rest of the logging/steps.
  home.activation.reloadSway = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    set +e
    log_dir="$HOME/.local/state/home-manager"
    mkdir -p "$log_dir"
    exec >>"$log_dir/reload-sway-emacs.log" 2>&1
    echo "---- $(date -Iseconds) ----"

    uid="$(id -u)"
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$uid}"

    # --- Sway ---
    sway_sock="$(ls -t "$XDG_RUNTIME_DIR"/sway-ipc.*.sock 2>/dev/null | head -n1)"
    if [ -S "$sway_sock" ]; then
      ${pkgs.sway}/bin/swaymsg -s "$sway_sock" reload && echo "sway: reloaded" || echo "sway: reload failed"
      # Sway reload re-enables all X11 outputs; restart multimon to reconfigure
      sleep 0.5
      systemctl --user restart xrdp-multimon 2>/dev/null && echo "multimon: restarted" || echo "multimon: restart failed"
    else
      echo "sway: skipped (no socket)"
    fi
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
