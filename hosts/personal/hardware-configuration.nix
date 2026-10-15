# Framework Laptop 13 (AMD Ryzen AI 300 Series / HX 370).
# Generated with `nixos-generate-config --no-filesystems`; filesystems, LUKS
# and swap come from ./disk.nix via disko.
{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
      inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
      ./disk.nix
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/persist".neededForBoot = true;

  impermanence-wipe = {
    enable = true;
    device = "/dev/mapper/pool-root";
    subvolume = "@/root";
    retentionDays = 30;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  # Radeon 890M: VA-API comes from mesa's radeonsi, enabled by hardware.graphics.
  hardware.graphics.enable = true;

  hardware.printers = {
    ensurePrinters = [
      {
        name = "holdens_printer";
        description = "HP LaserJet CP1025NW";
        location = "Home";
        deviceUri = "dnssd://HP%20LaserJet%20CP1025nw._pdl-datastream._tcp.local/";
        model = "HP/hp-laserjet_cp1025nw.ppd.gz";
      }
    ];
  };
}
