{
  pkgs,
  validation,
  containerValidation,
  source,
}:
let
  c = validation.config;
  enabled = containerValidation.config;
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
