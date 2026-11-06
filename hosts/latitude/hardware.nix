{ lib, ... }: {
  # Verified controller/initrd modules and firmware settings belong in local/latitude.nix.
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
