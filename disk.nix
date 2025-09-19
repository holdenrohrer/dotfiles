{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
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
            windows = {
              size = "60G";
              content = {
                type = "filesystem";
                format = "ntfs";
                mountpoint = "/mnt/win";
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                extraOpenArgs = [ ];
                settings = {
                  # if you want to use the key for interactive login be sure there is no trailing newline
                  # for example use `echo -n "password" > /tmp/secret.key`
                  keyFile = "/tmp/secret.key";
                  allowDiscards = true;
                };
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
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
            size = "100%";
            content = {
              type = "btrfs";
              mountOptions = [ "compress=zstd" "defaults" ];
              subvolumes = {
                "@/root" = {
                  mountpoint = "/";
                };
                "@/nix" = {
                  mountpoint = "/nix";
                };
                "@/persist" = {
                  mountpoint = "/persist";
                  neededForBoot = true;
                };
                "@/var-lib" = {
                  mountpoint = "/var/lib";
                };
                "@/var-cache" = {
                  mountpoint = "/var/cache";
                };
                "@/var-log" = {
                  mountpoint = "/var/log";
                  neededForBoot = true;
                };
                "@/var-tmp" = {
                  mountpoint = "/var/tmp";
                  neededForBoot = true;
                };
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
