{ config, ... }: {
  networking.firewall = {
    enable = true;
    allowedTCPPorts = config.services.openssh.ports;
  };
}
