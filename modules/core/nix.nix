{ ... }: {
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # `root` is included by NixOS; add the remote deployment administrator.
    trusted-users = [ "sam" ];
  };
  nix.gc = {
    automatic = false;
  };
}
