# Placeholder — disko handles filesystems; after first boot run
# `nixos-generate-config` and merge any extra detected hardware.
{ config, lib, pkgs, modulesPath, ... }:

{
  boot.initrd.availableKernelModules = [ "sd_mod" "sr_mod" "hv_vmbus" "hv_storvsc" ];
}
