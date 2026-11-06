{ config, lib, ... }: {
  options.homelab.backupJobs = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    description = "Reviewed native services.restic.backups jobs; credentials must be runtime paths, storage jobs need mount dependencies";
  };
  config.services.restic.backups = config.homelab.backupJobs;
}
