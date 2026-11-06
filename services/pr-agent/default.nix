{ config, lib, ... }: {
  options.homelab.prAgent.enable = lib.mkEnableOption "Qodo PR-Agent (implementation pending)";
  config.assertions = [
    {
      assertion = !config.homelab.prAgent.enable;
      message = "PR-Agent is blocked pending verified packaging and on-demand entry point";
    }
  ];
}
