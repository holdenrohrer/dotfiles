{ config, pkgs, lib, ... }:

# Reload the Emacs config into the *running* daemon on nixos-rebuild switch,
# instead of restarting it (which would kill every open tab / eat terminal).
#
# How: the init is exposed at a stable path that home-manager rewrites in
# place, and on each activation -- if the config actually changed and a daemon
# is up -- we ask the daemon to `(load ...)` it.
#
# SCOPE: this applies *elisp* config changes (keybindings, settings, defuns,
# hooks) live.  Adding / removing / patching an Emacs *package* changes the
# daemon's load-path, which a live process cannot adopt -- those still need
# `systemctl --user restart emacs` (the reload prints a reminder if it can't
# fully apply).  init.el should be written to be safe to re-evaluate
# (use-package/setq/keybindings are; one-shot imperative side effects are not).

{
  # Stable, in-place-updated copy of the init the daemon can reload.
  xdg.configFile."czar-emacs/init.el".source = ./init.el;

  home.activation.reloadEmacsConfig =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/czar-emacs/init.el"
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/czar-emacs"
      emacsclient="${config.programs.emacs.package}/bin/emacsclient"

      $DRY_RUN_CMD mkdir -p "$state"
      new_hash="$(${pkgs.coreutils}/bin/sha256sum "$cfg" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
      old_hash="$(${pkgs.coreutils}/bin/cat "$state/config-hash" 2>/dev/null || true)"

      if [ "$new_hash" != "$old_hash" ]; then
        if ${pkgs.procps}/bin/pgrep -xu "$USER" emacs > /dev/null 2>&1; then
          if $DRY_RUN_CMD "$emacsclient" --no-wait \
               --eval "(condition-case e (progn (load \"$cfg\") (message \"[nix] config reloaded\")) (error (message \"[nix] config reload error: %S\" e)))" \
               > /dev/null 2>&1; then
            echo "emacs: reloaded config into running daemon (tabs kept)"
          else
            echo "emacs: live reload failed; run 'systemctl --user restart emacs' to apply"
          fi
        fi
        $DRY_RUN_CMD sh -c 'printf %s "'"$new_hash"'" > "'"$state"'/config-hash"'
      fi
    '';
}
