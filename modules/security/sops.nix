{ ... }: {
  # No secrets are declared until encrypted files and recipients exist.
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = false;
}
