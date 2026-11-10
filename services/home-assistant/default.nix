{ pkgs, ... }:
let
  onboardingComponents = [
    "default_config"
    "met"
    "esphome"
    "zha"
  ];
in
{
  services.home-assistant = {
    enable = true;
    configDir = "/var/lib/home-assistant";
    # Setting this option replaces its onboarding defaults; retain them and add ZHA.
    # default_config supplies dhcp, ssdp, stream, and go2rtc dependencies.
    config = null;
    extraComponents = onboardingComponents;
    # NixOS 26.05's module ignores its computed components when the package has
    # its default empty extraComponents argument. Seed the package directly.
    package = pkgs.home-assistant.override {
      extraComponents = onboardingComponents;
    };
    openFirewall = false;
    openFirewallForComponents = false;
  };

  # ZHA lets the upstream NixOS module derive its serial-device policy while
  # retaining DevicePolicy=closed. Do not override those derived settings.
  networking.firewall.extraInputRules = ''
    iifname "eno2" ip saddr 192.168.8.0/24 tcp dport 8123 accept
  '';
}
