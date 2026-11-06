{ config, lib, ... }: {
  options.homelab.adminKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Verified administrator public keys";
  };
  config = {
    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = config.homelab.adminKeys;
      hashedPassword = "!";
    };
    # Remote elevation is explicit for this key-only administrator; Nix trust stays root-only.
    security.sudo.extraRules = [
      {
        users = [ "admin" ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
