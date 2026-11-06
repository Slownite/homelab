{ ... }: {
  imports = [
    ./ssh.nix
    ./firewall.nix
    ./tailscale.nix
  ];
  networking.useNetworkd = true;
  networking.useDHCP = false;
  # No interface match or DHCP policy is guessed. Supply it after inspection.
}
