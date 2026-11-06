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
    ];
    services.nfs.server = {
      enable = true;
      exports = cfg.exports;
    };
    systemd.services.nfs-server = {
      requires = [ "${utils.escapeSystemdPath cfg.mountPoint}.mount" ];
      after = [ "${utils.escapeSystemdPath cfg.mountPoint}.mount" ];
      bindsTo = [ "${utils.escapeSystemdPath cfg.mountPoint}.mount" ];
      unitConfig.ConditionPathIsMountPoint = cfg.mountPoint;
    };
    # Add interface/client-scoped firewall rules after discovering NFS version and clients.
  };
}
