{
  config,
  lib,
  pkgs,
  utils,
  hermesAgent,
  ...
}:
let
  cfg = config.homelab.hermes;
  stateDir = "/var/lib/homelab/hermes";
  notesPath = "/mnt/external_data/notes";
  nasMountPoint = "/mnt/external_data";
  nasMountUnit = "${utils.escapeSystemdPath nasMountPoint}.mount";
  notesAclService = "hermes-notes-acl";
  notesAclUnit = "${notesAclService}.service";
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
    environment.systemPackages = [ pkgs.acl ];
    systemd.services.${notesAclService} = {
      description = "Grant Hermes and sam access to the NAS notes vault";
      requires = [ nasMountUnit ];
      after = [ nasMountUnit ];
      bindsTo = [ nasMountUnit ];
      unitConfig = {
        RequiresMountsFor = nasMountPoint;
        ConditionPathIsMountPoint = nasMountPoint;
        ConditionPathIsDirectory = notesPath;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/test -d ${notesPath}";
      };
      path = [
        pkgs.acl
        pkgs.findutils
        pkgs.util-linux
      ];
      script = ''
        set -euo pipefail

        source="$(findmnt --noheadings --output SOURCE --target ${nasMountPoint})"
        test "$source" = /dev/md0

        setfacl --recursive --modify u:992:rwX,m::rwX ${notesPath}
        find ${notesPath} -type d -exec setfacl --modify \
          d:u:1000:rwx,d:u:992:rwx,d:m::rwx {} +
      '';
    };
    # networkd applies only the first matching .network file. The systemd
    # package's 80-container-ve.network matches ve-* and assigns a dynamic
    # subnet, so this must sort before it. The native container service owns
    # the veth's static address and peer route.
    systemd.network.networks."10-ve-hermes" = {
      matchConfig.Name = "ve-hermes";
      networkConfig = {
        IPv4Forwarding = true;
        LinkLocalAddressing = "no";
      };
    };

    # Scope egress NAT to packets received from Hermes, rather than addresses
    # configured on the host end of the veth. This renders an nftables rule
    # matching ve-hermes to eno2 and does not add any inbound forwarding.
    networking.nat = {
      enable = true;
      externalInterface = "eno2";
      internalInterfaces = [ "ve-hermes" ];
      forwardPorts = [ ];
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
      bindMounts."/mnt/notes" = {
        hostPath = notesPath;
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
        # The host's resolv.conf names its loopback-only resolved stub. Run an
        # independent resolver in the private namespace and reach its public
        # upstreams through the existing veth masquerade.
        networking.useHostResolvConf = lib.mkForce false;
        networking.nameservers = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        services.resolved.enable = true;
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

    systemd.services."container@hermes" = {
      requires = [
        nasMountUnit
        notesAclUnit
      ];
      after = [
        nasMountUnit
        notesAclUnit
      ];
      bindsTo = [ nasMountUnit ];
      unitConfig = {
        RequiresMountsFor = nasMountPoint;
        ConditionPathIsMountPoint = nasMountPoint;
        ConditionPathIsDirectory = notesPath;
      };
      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/test -d ${notesPath}";
        MemoryHigh = "5G";
        MemoryMax = "6G";
        CPUQuota = "300%";
        TasksMax = 512;
      };
    };
  };
}
