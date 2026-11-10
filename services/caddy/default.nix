{ ... }:
{
  services.caddy = {
    enable = true;
    # This is Caddy's persistent home and contains its internal CA and keys.
    dataDir = "/var/lib/caddy";
    openFirewall = false;

    # Keep the reload API available to the NixOS unit but inaccessible from the LAN.
    # HTTP redirects are intentionally disabled, so TCP port 80 stays closed.
    globalConfig = ''
      admin 127.0.0.1:2019
      auto_https disable_redirects
    '';

    virtualHosts."home.home.arpa" = {
      # Bind only the verified wired-LAN address; future services add another host here.
      listenAddresses = [ "192.168.8.100" ];
      extraConfig = ''
        tls internal
        reverse_proxy 127.0.0.1:8123
      '';
    };
  };

  # The persistent data directory contains the internal CA signing key.
  # Keep it private to the Caddy service account and root.
  systemd.services.caddy.serviceConfig.StateDirectoryMode = "0700";

  # Caddy's automatic WebSocket proxy support needs no separate directive.
  # Keep HTTPS scoped to the wired LAN instead of opening it globally.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i eno2 -s 192.168.8.0/24 -p tcp --dport 443 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i eno2 -s 192.168.8.0/24 -p tcp --dport 443 -j nixos-fw-accept 2>/dev/null || true
  '';
}
