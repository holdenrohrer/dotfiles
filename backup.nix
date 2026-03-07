{ pkgs, ... }:
{
  # Borg package available system-wide (for manual operations like `borg list`, `borg mount`)
  environment.systemPackages = [ pkgs.borgbackup ];

  programs.ssh.knownHosts."de4841.rsync.net" = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObQN4P/deJ/k4P4kXh6a9K4Q89qdyywYetp9h3nwfPo";
  };

  services.borgbackup.jobs.persist = {
    paths = [ "/persist" ];
    exclude = [
      "/persist/home/*/.cache"
      "/persist/home/*/.mozilla/firefox/*/storage/default/*/cache"
      "/persist/home/*/.mozilla/firefox/*/favicons.sqlite*"
    ];
    repo = "ssh://de4841@de4841.rsync.net/./borg";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat /persist/etc/borg/passphrase";
    };
    failOnWarnings = false;
    compression = "auto,zstd";
    startAt = "hourly";
    prune.keep = {
      hourly = 168;
      daily = 30;
      weekly = 12;
      monthly = 24;
      within = "1y";
    };
    environment = {
      BORG_RSH = "ssh -i /persist/etc/borg/id_ed25519";
      BORG_REMOTE_PATH = "borg14";
    };
    extraCreateArgs = "--stats";
  };

  # Trigger backup eagerly when network comes up, rate-limited to at most once per hour
  networking.networkmanager.dispatcherScripts = [{
    type = "basic";
    source = pkgs.writeScript "borgbackup-on-connect" ''
      #!/bin/sh
      if [ "$2" != "up" ] && [ "$2" != "connectivity-change" ]; then
        exit 0
      fi

      # Only act on connectivity-change if we actually have full connectivity
      if [ "$2" = "connectivity-change" ] && [ "$CONNECTIVITY_STATE" != "FULL" ]; then
        exit 0
      fi

      # Always retry if the last run failed
      result=$(systemctl show borgbackup-job-persist.service \
        --property=Result --value)
      if [ "$result" != "success" ]; then
        systemctl start borgbackup-job-persist.service
        exit 0
      fi

      # Rate limit: skip if last successful run was less than 1 hour ago
      last_run=$(systemctl show borgbackup-job-persist.service \
        --property=ExecMainStartTimestamp --value)
      if [ -n "$last_run" ]; then
        last_epoch=$(date -d "$last_run" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        if [ $((now_epoch - last_epoch)) -lt 3600 ]; then
          exit 0
        fi
      fi

      systemctl start borgbackup-job-persist.service
    '';
  }];
}
