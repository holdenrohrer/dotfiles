# Hyper-V Enhanced Session — xrdp serves Sway nested under Xwayland
{ config, pkgs, lib, ... }:

let
  pipewire-module-xrdp = pkgs.stdenv.mkDerivation rec {
    pname = "pipewire-module-xrdp";
    version = "0.1";

    src = pkgs.fetchFromGitHub {
      owner = "neutrinolabs";
      repo = "pipewire-module-xrdp";
      rev = "v${version}";
      hash = "sha256-ZiKVAMAFBkMpZFqrn4hjZZPxdR+sBtcd4W30z8pkdzk=";
    };

    nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config ];
    buildInputs = [ pkgs.pipewire ];

    configureFlags = [
      "--with-module-dir=${placeholder "out"}/lib/pipewire-0.3"
      "--with-xdgautostart-dir=${placeholder "out"}/etc/xdg/autostart"
    ];
  };

  swaySession = pkgs.writeShellScript "sway-xrdp" ''
    # Source home-manager session variables (QT theming, XDG dirs, etc.)
    . /etc/profiles/per-user/czar/etc/profile.d/hm-session-vars.sh

    # xrdp-specific overrides (must come after HM vars)
    export WLR_BACKENDS=x11
    export WLR_NO_HARDWARE_CURSORS=1
    export XDG_SESSION_TYPE=x11
    export MOZ_ENABLE_WAYLAND=0

    # Use "base" XKB rules to match xorgxrdp's keycode mapping (not evdev)
    export XKB_DEFAULT_RULES=base

    # Capture xrdp display info before sway changes DISPLAY
    export XRDP_XDISPLAY="$DISPLAY"

    # Create enough X11 outputs for any monitor configuration.
    # xorgxrdp reports monitors asynchronously, so we can't detect the
    # count here. The xrdp-multimon exec script disables unused outputs.
    export WLR_X11_OUTPUTS=6

    # Load xrdp audio sink into PipeWire
    export PIPEWIRE_MODULE_DIR="${pipewire-module-xrdp}/lib/pipewire-0.3:${pkgs.pipewire}/lib/pipewire-0.3"
    ${pipewire-module-xrdp}/libexec/pipewire-module-xrdp/load_pw_modules.sh &

    exec ${pkgs.sway}/bin/sway
  '';
in
{
  # Stub out xrdp-chansrv so sesexec doesn't run it — we manage it via systemd instead.
  nixpkgs.overlays = [(final: prev: {
    xrdp = prev.xrdp.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        mv $out/bin/xrdp-chansrv $out/bin/xrdp-chansrv-real
        cat > $out/bin/xrdp-chansrv <<'STUB'
#!/bin/sh
exec sleep infinity
STUB
        chmod +x $out/bin/xrdp-chansrv
      '';
    });
  })];

  virtualisation.hypervGuest.enable = true;

  # dxgkrnl for GPU-P (Intel Arc iGPU); hv_sock for enhanced session vsock
  boot.kernelModules = [ "dxgkrnl" "hv_sock" ];

  services.xrdp = {
    enable = true;
    openFirewall = true;
    defaultWindowManager = "${swaySession}";
    extraConfDirCommands = ''
      substituteInPlace $out/xrdp.ini \
        --replace-fail "port=3389" "port=vsock://-1:3389 3389" \
        --replace-fail "#vmconnect=true" "vmconnect=true" \
        --replace-fail "h264_frame_interval=16" "h264_frame_interval=8" \
        --replace-fail "rfx_frame_interval=32" "rfx_frame_interval=8" \
        --replace-fail "normal_frame_interval=40" "normal_frame_interval=8"
      sed -i '/^\[ChansrvLogging\]/,/^LogLevel=/{s/^LogLevel=.*/LogLevel=DEBUG/}' $out/sesman.ini
    '';
  };

  # NixOS module passes --port as integer, overriding vsock in xrdp.ini.
  systemd.services.xrdp.serviceConfig.ExecStart = lib.mkForce
    "${pkgs.xrdp}/bin/xrdp --nodaemon --config ${config.services.xrdp.confDir}/xrdp.ini";

  # Don't restart xrdp on rebuild — kills the active session
  systemd.services.xrdp.restartIfChanged = false;
  systemd.services.xrdp-sesman.restartIfChanged = false;

  # Activate graphical-session.target under xrdp (uwsm normally does this).
  # Starting this service pulls in the target via BindsTo dependency.
  systemd.user.services.xrdp-graphical-session = {
    description = "Activate graphical-session.target for xrdp";
    bindsTo = [ "graphical-session.target" ];
    after = [ "graphical-session-pre.target" ];
    wants = [ "graphical-session-pre.target" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
    };
  };

  # xrdp channel server (clipboard, audio, drive redirection) — managed by
  # systemd so it auto-restarts if it dies, unlike sesexec's built-in spawn.
  systemd.user.services.xrdp-chansrv = {
    description = "xrdp channel server";
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xrdp}/bin/xrdp-chansrv-real";
      Environment = "DISPLAY=:10";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Passwordless xrdp login for local user
  security.pam.services.xrdp-sesman.rules.auth.xrdp-autologin = {
    order = 0;
    control = "sufficient";
    modulePath = "pam_succeed_if.so";
    args = [ "user" "=" "czar" ];
  };
}
