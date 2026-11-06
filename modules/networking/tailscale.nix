{ lib, config, ... }: {
  options.homelab.tailscale.enable = lib.mkEnableOption "Tailscale (enroll manually after verified LAN SSH)";
  config.services.tailscale = {
    enable = config.homelab.tailscale.enable;
    openFirewall = false;
  };
}
