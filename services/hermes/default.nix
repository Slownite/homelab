{ config, lib, ... }: {
  options.homelab.hermes.enable = lib.mkEnableOption "Hermes (implementation pending)";
  config.assertions = [
    {
      assertion = !config.homelab.hermes.enable;
      message = "Hermes is blocked pending package/runtime verification and state migration review";
    }
  ];
}
