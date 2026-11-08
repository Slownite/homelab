{
  config,
  lib,
  hermesAgent,
  ...
}:
let
  cfg = config.homelab.hermes;
  stateDir = "/var/lib/homelab/hermes";
in
{
  options.homelab.hermes = {
    enable = lib.mkEnableOption "Hermes in a native NixOS container";
    gateway.enable = lib.mkEnableOption "the restored Hermes Discord gateway";
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 992 992 - -"
    ];

    # The veth only connects Hermes to the host. networkd masquerades its
    # egress; no host port is forwarded into the container.
    systemd.network.networks."80-ve-hermes" = {
      matchConfig.Name = "ve-hermes";
      networkConfig = {
        IPv4Forwarding = true;
        IPMasquerade = "ipv4";
      };
    };

    containers.hermes = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "10.231.136.1";
      localAddress = "10.231.136.2";
      privateUsers = "identity";
      bindMounts.${stateDir} = {
        hostPath = stateDir;
        isReadOnly = false;
      };

      # nixos-containers otherwise exposes the host Nix daemon socket. Hermes
      # runs the sealed upstream package and must not build or install through
      # the host daemon.
      tmpfs = [ "/nix/var/nix/daemon-socket" ];

      config = { lib, ... }: {
        imports = [ hermesAgent.nixosModules.default ];

        system.stateVersion = "26.05";
        nix.enable = false;
        networking.useHostResolvConf = true;
        networking.firewall.enable = true;

        users.groups.hermes.gid = 992;
        users.users.hermes = {
          isSystemUser = true;
          uid = 992;
          group = "hermes";
          home = stateDir;
          createHome = false;
        };

        services.hermes-agent = {
          enable = true;
          container.enable = false;
          createUser = false;
          user = "hermes";
          group = "hermes";
          inherit stateDir;
          workingDirectory = "${stateDir}/workspace";
          restart = "always";
          restartSec = 5;
          backend.mode = "none";
        };

        # Stage A creates and validates the container without making an
        # outbound Discord connection. Stage B requires a deliberate config
        # change and a root-owned marker created only after state restoration.
        systemd.services.hermes-agent = {
          wantedBy = lib.mkForce (lib.optional cfg.gateway.enable "multi-user.target");
          unitConfig.ConditionPathExists = lib.mkIf cfg.gateway.enable "${stateDir}/.gateway-enabled";
        };
      };
    };

    systemd.services."container@hermes".serviceConfig = {
      MemoryHigh = "5G";
      MemoryMax = "6G";
      CPUQuota = "300%";
      TasksMax = 512;
    };
  };
}
