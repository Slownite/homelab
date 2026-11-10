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

  # Keep the Home Assistant frontend scoped to the wired LAN; this is emitted
  # with NixOS's iptables firewall lifecycle rather than opening port 8123 globally.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i eno2 -s 192.168.8.0/24 -p tcp --dport 8123 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i eno2 -s 192.168.8.0/24 -p tcp --dport 8123 -j nixos-fw-accept 2>/dev/null || true
  '';
}
