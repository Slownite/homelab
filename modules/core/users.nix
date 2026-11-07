{ config, lib, ... }: {
  options.homelab.adminUser = lib.mkOption {
    type = lib.types.str;
    default = "admin";
    description = "Installed administrator account";
  };
  options.homelab.adminKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Verified administrator public keys";
  };
  config = {
    users.users.${config.homelab.adminUser} = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = config.homelab.adminKeys;
      hashedPassword = "!";
      mutableUsers = true;
    };
    # Remote elevation is explicit for this key-only administrator; Nix trust stays root-only.
    security.sudo.extraRules = [
      {
        users = [ config.homelab.adminUser ];
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
