# Import only in a dedicated installation-test configuration.
{
  config,
  lib,
  pkgs,
  extendModules,
  diskoLib,
  ...
}:
{
  system.build.installTest = lib.mkForce (
    diskoLib.testLib.makeDiskoTest {
      inherit pkgs extendModules;
      name = "latitude-production-layout";
      disko-config = builtins.removeAttrs config [ "_module" ];
      testMode = "direct";
      efi = true;
      extraInstallerConfig = {
        virtualisation.emptyDiskImages = lib.mkForce [ 32768 ];
      };
    }
  );
}
