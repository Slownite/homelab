{ lib, ... }: {
  # Evaluation fixture only: not a description of Latitude hardware.
  boot.isContainer = true;
  networking.useHostResolvConf = false;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  assertions = [
    {
      assertion = false;
      message = "Validation fixture is deliberately non-deployable";
    }
  ];
}
