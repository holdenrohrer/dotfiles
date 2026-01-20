{ config, lib, pkgs, ... }:

let
  # Helper to create WPA-PSK network profiles
  mkWpaNetwork = { ssid, psk, priority ? 0, autoconnect ? true }: {
    connection = {
      id = ssid;
      type = "wifi";
      autoconnect = lib.boolToString autoconnect;
      autoconnect-priority = toString priority;
    };
    wifi = {
      mode = "infrastructure";
      ssid = ssid;
    };
    wifi-security = {
      auth-alg = "open";
      key-mgmt = "wpa-psk";
      psk = psk;
    };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };

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
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";

    ensureProfiles.profiles = {
      # === HOME / HIGH PRIORITY ===
      "404networknotfound" = mkWpaNetwork {
        ssid = "404networknotfound";
        psk = "REDACTED";
        priority = 100;
      };

      "Holden R" = mkWpaNetwork {
        ssid = "Holden R";
        psk = "REDACTED";
        priority = 10;
      };

      "BHNTG1672G54C2-5G" = mkWpaNetwork {
        ssid = "BHNTG1672G54C2-5G";
        psk = "REDACTED";
        priority = 1;
      };

      "FLTech-Guest" = mkWpaNetwork {
        ssid = "FLTech-Guest";
        psk = "REDACTED";
        priority = 1;
      };

      # === EDUROAM (WPA-EAP) ===
      "eduroam" = {
        connection = {
          id = "eduroam";
          type = "wifi";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "eduroam";
        };
        wifi-security = {
          key-mgmt = "wpa-eap";
        };
        "802-1x" = {
          eap = "peap;";
          identity = "hrohrer3@gatech.edu";
          password = "REDACTED";
          phase2-auth = "mschapv2";
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };

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

      # === REGULAR WPA-PSK NETWORKS ===
      "TDS2219" = mkWpaNetwork { ssid = "TDS2219"; psk = "REDACTED"; };
      "Verizon-MiFi8800L-81AC" = mkWpaNetwork { ssid = "Verizon-MiFi8800L-81AC"; psk = "REDACTED"; };
      "Gizmoclub5" = mkWpaNetwork { ssid = "Gizmoclub5"; psk = "REDACTED"; };
      "BHNTG1672G54C2" = mkWpaNetwork { ssid = "BHNTG1672G54C2"; psk = "REDACTED"; };
      "SpectrumSetup-10" = mkWpaNetwork { ssid = "SpectrumSetup-10"; psk = "REDACTED"; };
      "MySpectrumWiFia0-5G" = mkWpaNetwork { ssid = "MySpectrumWiFia0-5G"; psk = "REDACTED"; };
      "Beckman Family-5G" = mkWpaNetwork { ssid = "Beckman Family-5G"; psk = "REDACTED"; };
      "Beckman Family" = mkWpaNetwork { ssid = "Beckman Family"; psk = "REDACTED"; priority = -1; };
      "WIN5_104072" = mkWpaNetwork { ssid = "WIN5_104072"; psk = "REDACTED"; };
      "WIN_104072" = mkWpaNetwork { ssid = "WIN_104072"; psk = "REDACTED"; };
      "OscarFitz" = mkWpaNetwork { ssid = "OscarFitz"; psk = "REDACTED"; };
      "ATTFT83VbA" = mkWpaNetwork { ssid = "ATTFT83VbA"; psk = "REDACTED"; };
      "CenturyLink3733" = mkWpaNetwork { ssid = "CenturyLink3733"; psk = "REDACTED"; };
      "MartinHome" = mkWpaNetwork { ssid = "MartinHome"; psk = "REDACTED"; };
      "LTNet5" = mkWpaNetwork { ssid = "LTNet5"; psk = "REDACTED"; };
      "ATT78w62JY" = mkWpaNetwork { ssid = "ATT78w62JY"; psk = "REDACTED"; };
      "Vodafone-F31A" = mkWpaNetwork { ssid = "Vodafone-F31A"; psk = "REDACTED"; };
      "McDaniel" = mkWpaNetwork { ssid = "McDaniel"; psk = "REDACTED"; };
      "babilon-office2" = mkWpaNetwork { ssid = "babilon-office2"; psk = "REDACTED"; };
      "Vodafone-D4A5" = mkWpaNetwork { ssid = "Vodafone-D4A5"; psk = "REDACTED"; };
      "Vodafone-BB8D" = mkWpaNetwork { ssid = "Vodafone-BB8D"; psk = "REDACTED"; };
      "FiberHGW_ZT3P22_5GHz" = mkWpaNetwork { ssid = "FiberHGW_ZT3P22_5GHz"; psk = "REDACTED"; };
      "Vodafone-6C22" = mkWpaNetwork { ssid = "Vodafone-6C22"; psk = "REDACTED"; };
      "DolceVita" = mkWpaNetwork { ssid = "DolceVita"; psk = "REDACTED"; };
      "Vodafone-F42D" = mkWpaNetwork { ssid = "Vodafone-F42D"; psk = "REDACTED"; };
      "Leverett5G" = mkWpaNetwork { ssid = "Leverett5G"; psk = "REDACTED"; };
      "Network 2 5Ghz" = mkWpaNetwork { ssid = "Network 2 5Ghz"; psk = "REDACTED"; };
      "Cafe Au - LaitGuest" = mkWpaNetwork { ssid = "Cafe Au - LaitGuest"; psk = "REDACTED"; };
      "Modern Animal Guest" = mkWpaNetwork { ssid = "Modern Animal Guest"; psk = "REDACTED"; };
      "Cotton1125" = mkWpaNetwork { ssid = "Cotton1125"; psk = "REDACTED"; };
      "Sweet Hut" = mkWpaNetwork { ssid = "Sweet Hut"; psk = "REDACTED"; };
      "aaacm" = mkWpaNetwork { ssid = "aaacm"; psk = "REDACTED"; };
      "1105east9th" = mkWpaNetwork { ssid = "1105east9th"; psk = "REDACTED"; };
      "Brazil 4 You 5G" = mkWpaNetwork { ssid = "Brazil 4 You 5G"; psk = "REDACTED"; };
      "TP-Link_C524" = mkWpaNetwork { ssid = "TP-Link_C524"; psk = "REDACTED"; };
      "U&Me" = mkWpaNetwork { ssid = "U&Me"; psk = "REDACTED"; };
      "ELKA" = mkWpaNetwork { ssid = "ELKA"; psk = "REDACTED"; };
      "HIM" = mkWpaNetwork { ssid = "HIM"; psk = "REDACTED"; };
      "Grants iPhone" = mkWpaNetwork { ssid = "Grants iPhone"; psk = "REDACTED"; };
      "McTurk-5" = mkWpaNetwork { ssid = "McTurk-5"; psk = "REDACTED"; };
      "TheGeneralMuir" = mkWpaNetwork { ssid = "TheGeneralMuir"; psk = "REDACTED"; };
      "Condohome" = mkWpaNetwork { ssid = "Condohome"; psk = "REDACTED"; };
      "Quisby Guest" = mkWpaNetwork { ssid = "Quisby Guest"; psk = "REDACTED"; };
      "Ground and Pound Coffee - Guests" = mkWpaNetwork { ssid = "Ground and Pound Coffee - Guests"; psk = "REDACTED"; };
    };
  };
}
