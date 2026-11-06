{ config, lib, ... }:
let
  cfg = config.homelab.install;
in
{
  options.homelab.install = {
    internalDisk = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Verified internal whole-disk /dev/disk/by-id path";
    };
    uefiConfirmed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Firmware inspection confirmed UEFI";
    };
  };
  config = lib.mkIf (cfg.internalDisk != null) {
    assertions = [
      {
        assertion =
          lib.hasPrefix "/dev/disk/by-id/" cfg.internalDisk && !(lib.hasInfix "-part" cfg.internalDisk);
        message = "Use an inspected persistent whole internal disk ID";
      }
      {
        assertion = cfg.uefiConfirmed;
        message = "This layout requires confirmed UEFI; design a different layout for legacy BIOS";
      }
    ];
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    # Removable fallback boot path avoids assuming remote firmware-variable access.
    disko.devices.disk.internal = {
      type = "disk";
      device = cfg.internalDisk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
