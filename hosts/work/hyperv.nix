# Hyper-V Enhanced Session — xrdp serves Sway nested under Xwayland
{ pkgs, ... }:

let
  swaySession = pkgs.writeShellScript "sway-xrdp" ''
    export WLR_BACKENDS=x11
    export WLR_NO_HARDWARE_CURSORS=1
    export XDG_SESSION_TYPE=x11
    export MOZ_ENABLE_WAYLAND=0
    exec ${pkgs.sway}/bin/sway
  '';
in
{
  virtualisation.hypervGuest.enable = true;

  # dxgkrnl for GPU-P (Intel Arc iGPU paravirtualization)
  boot.kernelModules = [ "dxgkrnl" ];

  services.xrdp = {
    enable = true;
    openFirewall = true;
    defaultWindowManager = "${swaySession}";
  };
}
