{ config, lib, ... }: {
  options.homelab.exampleContainer.enable = lib.mkEnableOption "offline demonstration NixOS container";
  config = lib.mkIf config.homelab.exampleContainer.enable {
    containers.example = {
      autoStart = false;
      privateNetwork = true;
      # No veth, forwarding, bind mounts or host devices; loopback only.
      config = { pkgs, ... }: {
        system.stateVersion = "26.05";
        networking.useDHCP = false;
        networking.useHostResolvConf = false;
        networking.firewall.enable = true;
        systemd.services.demo = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.coreutils}/bin/sleep infinity";
            DynamicUser = true;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            Restart = "on-failure";
          };
        };
      };
    };
    systemd.services."container@example".serviceConfig = {
      MemoryMax = "256M";
      CPUQuota = "25%";
      TasksMax = 128;
    };
  };
}
