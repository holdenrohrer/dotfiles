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
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # Read only at format time to set the passphrase; boot prompts
                # interactively. Write it with no trailing newline:
                #   read -rs p && printf %s "$p" > /tmp/secret.key
                passwordFile = "/tmp/secret.key";
                settings.allowDiscards = true;
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
          # Swap first so it gets a fixed size; it backs hibernate (30G RAM).
          swap = {
            size = "32G";
            content = {
              type = "swap";
              resumeDevice = true;
            };
          };
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              # Same semantics as the old ThinkPad layout: everything not on
              # /nix, /persist or /cache is wiped every boot.
              subvolumes = {
                "@/root" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@/nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@/persist" = { mountpoint = "/persist"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@/cache" = { mountpoint = "/cache"; mountOptions = [ "compress=zstd" "noatime" ]; };
              };
            };
          };
        };
      };
    };
  };
}
