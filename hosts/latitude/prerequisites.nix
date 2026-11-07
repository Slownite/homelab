{ config, ... }: {
  assertions = [
    {
      assertion = config.homelab.install.internalDisk != null;
      message = "Internal disk inspection required";
    }
    {
      assertion = config.homelab.adminKeys != [ ];
      message = "Verified administrator keys required";
    }
    {
      assertion = config.systemd.network.networks != { };
      message = "Verified network configuration required";
    }
  ];
}
