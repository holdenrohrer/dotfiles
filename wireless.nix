{ config, lib, pkgs, ... }:

let
  # Helper for open networks
  mkOpenNetwork = { ssid, priority ? 0 }: {
    connection = {
      id = ssid;
      type = "wifi";
      autoconnect-priority = toString priority;
    };
    wifi = {
      mode = "infrastructure";
      ssid = ssid;
    };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };

in {
  networking.hostName = "nixos";

  # Disable old stack
  networking.wireless.enable = false;
  networking.dhcpcd.enable = false;

  # Enable iwd
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        EnableNetworkConfiguration = false; # Let NetworkManager handle DHCP
      };
      Network = {
        EnableIPv6 = true;
      };
    };
  };

  # Enable NetworkManager with iwd backend
  # PSK networks are managed imperatively via nmcli:
  #   nmcli dev wifi connect "SSID" password "PSK"
  # Connections persist in /etc/NetworkManager/system-connections (via impermanence)
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";

    ensureProfiles.profiles = {
      # === OPEN NETWORKS ===
      "HERE Guest" = mkOpenNetwork { ssid = "HERE Guest"; };
      "Starbucks WiFi" = mkOpenNetwork { ssid = "Starbucks WiFi"; };
      "ATL Free Wi-Fi" = mkOpenNetwork { ssid = "ATL Free Wi-Fi"; };

      # GTVisitor - disabled
      "GTVisitor" = {
        connection = {
          id = "GTVisitor";
          type = "wifi";
          autoconnect = "false";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "GTVisitor";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };
  };
}
