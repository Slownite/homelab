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

  # Caddy is the only LAN entry point. Home Assistant remains reachable to
  # Caddy over loopback, which never requires a firewall exception.
}
