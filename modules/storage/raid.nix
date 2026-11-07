{ config, lib, ... }:
let
  cfg = config.homelab.externalRaid;
in
{
  options.homelab.externalRaid = {
    enable = lib.mkEnableOption "assembly and mounting of the existing external RAID (never creation)";
    arrayUUID = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    filesystemUUID = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    arrayName = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.all (v: v != "") [
          cfg.arrayUUID
          cfg.filesystemUUID
          cfg.arrayName
          cfg.mountPoint
        ];
        message = "Existing RAID requires audited identities and mountpoint";
      }
    ];
    boot.swraid = {
      enable = true;
      mdadmConf = ''
        AUTO -all
        ARRAY /dev/md0 UUID=${cfg.arrayUUID} name=${cfg.arrayName}
        PROGRAM /run/current-system/sw/bin/logger
      '';
    };
    # UUID matching, not kernel enumeration, identifies the existing filesystem.
    fileSystems.${cfg.mountPoint} = {
      device = "/dev/disk/by-uuid/${cfg.filesystemUUID}";
      fsType = "ext4";
      options = [
        "nofail"
        "x-systemd.device-timeout=30s"
      ];
      # Preserve data: no automatic boot-time filesystem repair.
      noCheck = true;
    };
  };
}
