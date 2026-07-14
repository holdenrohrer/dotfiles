{ config, lib, ... }:

let
  cfg = config.impermanence-wipe;
in {
  options.impermanence-wipe = {
    enable = lib.mkEnableOption "boot-time btrfs root wipe for impermanence";

    device = lib.mkOption {
      type = lib.types.str;
      description = "Btrfs device to mount for root subvolume wipe (e.g. /dev/mapper/pool-root)";
    };

    subvolume = lib.mkOption {
      type = lib.types.str;
      default = "@root";
      description = "Btrfs subvolume path for root (e.g. @root for flat layout, @/root for disko nested layout)";
    };

    retentionDays = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Delete old root snapshots after this many days. null = keep forever.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.postResumeCommands = lib.mkAfter ''
      mkdir /btrfs_tmp
      mount ${cfg.device} /btrfs_tmp
      if [[ -e /btrfs_tmp/${cfg.subvolume} ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/${cfg.subvolume})" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/${cfg.subvolume} "/btrfs_tmp/old_roots/$timestamp"
      fi
      ${lib.optionalString (cfg.retentionDays != null) ''
        delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
        }

        for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +${toString cfg.retentionDays}); do
          delete_subvolume_recursively "$i"
        done
      ''}
      btrfs subvolume create /btrfs_tmp/${cfg.subvolume}
      umount /btrfs_tmp
    '';

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/lib/nixos"
        "/etc/NetworkManager/system-connections"
        "/root/.cache/borg"
        "/root/.config/borg"
      ];
      files = [
        "/etc/machine-id"
      ];
      users.czar = {
        directories = [
          ".mozilla"
          ".vim"
          ".gnupg"
          ".ssh"
          ".password-store"
          "brain"
          "projects"
          ".local/share/direnv/allow"
          ".cache/nix-index"
          ".claude"
          ".codex"
          ".config/gh"
          # gptel's ChatGPT/Codex OAuth device-flow token, so the login
          # survives the boot-time root wipe instead of re-authing each boot.
          ".emacs.d/.cache/gptel-openai"
        ];
        files = [
          ".claude.json"
        ];
      };
    };
  };
}
