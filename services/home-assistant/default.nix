{ lib, ... }:
{
  services.home-assistant = {
    enable = true;
    configDir = "/var/lib/home-assistant";
    # Leave configuration.yaml UI-managed so onboarding and later UI changes persist.
    config = null;
    extraComponents = lib.mkAfter [ "zha" ];
    openFirewall = false;
    openFirewallForComponents = false;
  };

  # ZHA lets the upstream NixOS module derive its serial-device policy while
  # retaining DevicePolicy=closed. Do not override those derived settings.
  networking.firewall.extraInputRules = ''
    iifname "eno2" ip saddr 192.168.8.0/24 tcp dport 8123 accept
  '';
}
