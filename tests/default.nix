{
  pkgs,
  validation,
  containerValidation,
  hermesValidation,
  source,
}:
let
  c = validation.config;
  enabled = containerValidation.config;
  hermes = hermesValidation.config;
  hermesActivation =
    (hermesValidation.extendModules {
      modules = [ { homelab.hermes.gateway.enable = true; } ];
    }).config;
  # Synthetic loopback-only NFS fixture; never a physical-storage configuration.
  nfs =
    (validation.extendModules {
      modules = [
        {
          homelab.nfs = {
            enable = true;
            mountPoint = "/srv/fixture";
            exports = "/srv/fixture 127.0.0.1(ro,root_squash,mountpoint)";
          };
          fileSystems."/srv/fixture" = {
            device = "none";
            fsType = "tmpfs";
          };
        }
      ];
    }).config;
  # Non-deployable RAID module fixture; no block device or array is created.
  raid =
    (validation.extendModules {
      modules = [
        {
          homelab.externalRaid = {
            enable = true;
            arrayUUID = "evaluation-only";
            filesystemUUID = "evaluation-only";
            arrayName = "evaluation-only";
            mountPoint = "/srv/raid-fixture";
          };
        }
      ];
    }).config;
  # Force module data without building a bootable system or bypassing its assertions.
  report = builtins.toJSON {
    ssh = c.services.openssh.settings;
    firewall = c.networking.firewall.enable;
    disks = builtins.attrNames c.disko.devices.disk;
    containerService = enabled.containers.example.config.systemd.services.demo.serviceConfig;
    limits = enabled.systemd.services."container@example".serviceConfig.MemoryMax;
  };
  ensure = condition: message: if condition then true else throw message;
  checkAssertions =
    cfg:
    let
      failed = builtins.filter (
        a: !a.assertion && a.message != "Validation fixture is deliberately non-deployable"
      ) cfg.assertions;
    in
    if failed == [ ] then true else throw (builtins.concatStringsSep "\n" (map (a: a.message) failed));
  production =
    (validation.extendModules {
      modules = [ { homelab.install.internalDisk = "/dev/disk/by-id/evaluation-only"; } ];
    }).config.disko.devices.disk.internal.content.partitions;
  tests = [
    (ensure (
      production.ESP.size == "1G" && production.swap.size == "16G"
    ) "Production EFI/swap sizes regressed")
    (ensure (checkAssertions raid) "RAID module assertion failed")
    (ensure (raid.boot.swraid.enable && raid.disko.devices.disk == { }) "RAID must not enter Disko")
    (ensure (raid.fileSystems."/srv/raid-fixture".noCheck
    ) "Existing RAID must not be automatically repaired")
    (ensure (builtins.elem "nofail"
      raid.fileSystems."/srv/raid-fixture".options
    ) "Missing RAID must not prevent admin recovery")
    (ensure (builtins.elem "srv-fixture.mount" nfs.systemd.services.nfs-server.bindsTo) "NFS must stop with its data mount")
    (ensure (
      nfs.systemd.services.nfs-server.unitConfig.ConditionPathIsMountPoint == "/srv/fixture"
    ) "NFS needs mountpoint guard")
    (ensure (checkAssertions nfs) "NFS fixture assertions failed")
    (ensure (checkAssertions c) "Base module assertion failed")
    (ensure (checkAssertions enabled) "Enabled container host assertion failed")
    (ensure (builtins.all (
      a: a.assertion
    ) enabled.containers.example.config.assertions) "Container module assertion failed")
    (ensure (c.disko.devices.disk == { }) "No disk may be selected by validation")
    (ensure (!c.services.nfs.server.enable) "NFS must default off")
    (ensure (c.services.restic.backups == { }) "Backups must default off")
    (ensure (!c.homelab.hermes.enable && !c.homelab.prAgent.enable) "Agents must default off")
    (ensure (c.containers == { }) "Example must default off")
    (ensure (
      enabled.containers.example.privateNetwork && enabled.containers.example.bindMounts == { }
    ) "Container must be private without mounts")
    (ensure (
      !c.services.openssh.settings.PasswordAuthentication && c.networking.firewall.enable
    ) "SSH/firewall policy regressed")
    (ensure (checkAssertions hermes) "Hermes container assertion failed")
    (ensure (
      hermes.containers.hermes.autoStart
      && hermes.containers.hermes.privateNetwork
      && hermes.containers.hermes.hostAddress == "10.231.136.1"
      && hermes.containers.hermes.localAddress == "10.231.136.2"
      && hermes.containers.hermes.forwardPorts == [ ]
    ) "Hermes must autostart privately with no inbound ports")
    (ensure (
      hermes.containers.hermes.bindMounts."/var/lib/homelab/hermes".hostPath == "/var/lib/homelab/hermes"
      && !hermes.containers.hermes.bindMounts."/var/lib/homelab/hermes".isReadOnly
      && hermes.containers.hermes.bindMounts."/mnt/notes".hostPath == "/mnt/external_data/notes"
      && !hermes.containers.hermes.bindMounts."/mnt/notes".isReadOnly
      &&
        builtins.attrNames hermes.containers.hermes.bindMounts == [
          "/mnt/notes"
          "/var/lib/homelab/hermes"
        ]
      && hermes.containers.hermes.privateUsers == "identity"
    ) "Hermes must receive only its writable state and notes mounts")
    (ensure (
      hermes.containers.hermes.config.nix.enable == false
      && hermes.containers.hermes.config.services.hermes-agent.container.enable == false
      && !hermes.containers.hermes.config.networking.useHostResolvConf
      && hermes.containers.hermes.config.services.resolved.enable
      &&
        hermes.containers.hermes.config.networking.nameservers == [
          "1.1.1.1"
          "1.0.0.1"
        ]
      && !hermes.virtualisation.docker.enable
      && builtins.elem "/nix/var/nix/daemon-socket" hermes.containers.hermes.tmpfs
    ) "Hermes must use its own resolver with reachable upstream DNS")
    (ensure
      (
        hermes.networking.nat.enable
        && hermes.networking.nat.externalInterface == "eno2"
        && hermes.networking.nat.internalInterfaces == [ "ve-hermes" ]
        && hermes.networking.nat.forwardPorts == [ ]
        && hermes.systemd.network.networks."10-ve-hermes".address == [ ]
        && hermes.systemd.network.networks."10-ve-hermes".routes == [ ]
        && !(hermes.systemd.network.networks ? "80-ve-hermes")
        && !(hermes.systemd.network.networks."10-ve-hermes".networkConfig ? IPMasquerade)
        && hermes.systemd.network.networks."10-ve-hermes".networkConfig.IPv4Forwarding
        && hermes.systemd.network.networks."10-ve-hermes".networkConfig.LinkLocalAddressing == "no"
      )
      "Hermes must use native container addresses with NAT, forwarding, and no duplicate networkd configuration"
    )
    (ensure (
      hermes.containers.hermes.config.users.groups.hermes.gid == 992
      && hermes.containers.hermes.config.users.users.hermes.uid == 992
      && hermes.containers.hermes.config.services.hermes-agent.user == "hermes"
      && hermes.containers.hermes.config.services.hermes-agent.group == "hermes"
      &&
        hermes.containers.hermes.config.systemd.services.hermes-agent.environment.HOME
        == "/var/lib/homelab/hermes"
      &&
        hermes.containers.hermes.config.systemd.services.hermes-agent.environment.HERMES_HOME
        == "/var/lib/homelab/hermes/.hermes"
      &&
        hermes.containers.hermes.config.systemd.services.hermes-agent.serviceConfig.WorkingDirectory
        == "/var/lib/homelab/hermes/workspace"
    ) "Hermes service must retain its persistent home and identity")
    (ensure (
      hermes.systemd.services."container@hermes".serviceConfig.MemoryHigh == "5G"
      && hermes.systemd.services."container@hermes".serviceConfig.MemoryMax == "6G"
      && hermes.systemd.services."container@hermes".serviceConfig.CPUQuota == "300%"
      && hermes.systemd.services."container@hermes".serviceConfig.TasksMax == 512
    ) "Hermes container limits regressed")
    (ensure (
      builtins.elem "mnt-external_data.mount" hermes.systemd.services."container@hermes".requires
      && builtins.elem "hermes-notes-acl.service" hermes.systemd.services."container@hermes".requires
      && builtins.elem "mnt-external_data.mount" hermes.systemd.services."container@hermes".after
      && builtins.elem "hermes-notes-acl.service" hermes.systemd.services."container@hermes".after
      && hermes.systemd.services."container@hermes".bindsTo == [ "mnt-external_data.mount" ]
      &&
        hermes.systemd.services."container@hermes".unitConfig.ConditionPathIsMountPoint
        == "/mnt/external_data"
      &&
        hermes.systemd.services."container@hermes".unitConfig.ConditionPathIsDirectory
        == "/mnt/external_data/notes"
      && hermes.systemd.services."hermes-notes-acl".requires == [ "mnt-external_data.mount" ]
      && hermes.systemd.services."hermes-notes-acl".bindsTo == [ "mnt-external_data.mount" ]
      &&
        hermes.systemd.services."hermes-notes-acl".unitConfig.ConditionPathIsMountPoint
        == "/mnt/external_data"
      &&
        hermes.systemd.services."hermes-notes-acl".unitConfig.ConditionPathIsDirectory
        == "/mnt/external_data/notes"
    ) "Hermes notes access must fail closed on the NAS mount")
    (ensure (
      hermes.containers.hermes.config.systemd.services.hermes-agent.wantedBy == [ ]
    ) "Stage A must leave the gateway stopped")
    (ensure (
      hermesActivation.containers.hermes.config.systemd.services.hermes-agent.wantedBy
      == [ "multi-user.target" ]
      &&
        hermesActivation.containers.hermes.config.systemd.services.hermes-agent.unitConfig.ConditionPathExists
        == "/var/lib/homelab/hermes/.gateway-enabled"
    ) "Stage B must require explicit activation after restoration")
  ];
in
{
  formatting = pkgs.runCommand "nix-formatting" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    find ${source} -name '*.nix' -type f -print0 | xargs -0 nixfmt --check
    touch $out
  '';
  module-evaluation =
    assert builtins.deepSeq tests true;
    pkgs.writeText "module-evaluation.json" report;
}
