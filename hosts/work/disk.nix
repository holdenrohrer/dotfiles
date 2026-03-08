{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            lvm = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              mountOptions = [ "compress=zstd" "defaults" ];
              subvolumes = {
                "@/root"      = { mountpoint = "/"; };
                "@/nix"       = { mountpoint = "/nix"; };
                "@/persist"   = { mountpoint = "/persist"; };
                "@/var-lib"   = { mountpoint = "/var/lib"; };
                "@/var-cache" = { mountpoint = "/var/cache"; };
                "@/var-log"   = { mountpoint = "/var/log"; };
                "@/var-tmp"   = { mountpoint = "/var/tmp"; };
              };
            };
          };
          swap = {
            size = "16G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
        };
      };
    };
  };
}
