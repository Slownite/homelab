{ ... }: {
  imports = [
    ../../modules/core
    ../../modules/networking
    ../../modules/storage
    ../../modules/security
    ../../modules/containers
    ../../services/caddy
    ../../services/hermes
    ../../services/home-assistant
    ../../services/pr-agent
    ./hardware.nix
    ./disko.nix
  ];
  networking.hostName = "latitude";
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05";
}
