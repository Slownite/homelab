{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.homelab.nfs;
in
{
  options.homelab.nfs = {
    enable = lib.mkEnableOption "inspected NFS exports";
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    exports = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Inspected least-privilege exports; never wildcard clients or no_root_squash";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mountPoint != "" && cfg.exports != "";
        message = "NFS needs an inspected mountpoint and exports";
      }

      {
        assertion = lib.hasInfix ",mountpoint" cfg.exports;
        message = "NFS exports must include mountpoint to refuse an absent filesystem";
      }

    ];
    services.nfs.server = {
      enable = true;
      exports = cfg.exports;
      extraNfsdConfig = ''
        vers3 = n
        vers4 = y
        vers4.2 = y
        udp = n
      '';
    };
    systemd.services.nfs-server = {
      requires = [ "${utils.escapeSystemdPath cfg.mountPoint}.mount" ];
      after = [ "${utils.escapeSystemdPath cfg.mountPoint}.mount" ];
      bindsTo = [ "${utils.escapeSystemdPath cfg.mountPoint}.mount" ];
      unitConfig = {
        RequiresMountsFor = cfg.mountPoint;
        ConditionPathIsMountPoint = cfg.mountPoint;
      };
    };
    # exportfs refuses the underlying directory even during mount-loss races.
    # Private profiles must include the exports(5) "mountpoint" option.
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -s 192.168.8.0/24 -p tcp --dport 2049 -j nixos-fw-accept
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D nixos-fw -s 192.168.8.0/24 -p tcp --dport 2049 -j nixos-fw-accept 2>/dev/null || true
    '';
  };
}
