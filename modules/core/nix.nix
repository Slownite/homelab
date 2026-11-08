{ ... }: {
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "sam"
    ];
  };
  nix.gc = {
    automatic = false;
  };
}
