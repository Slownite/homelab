# Initial installation — future authorized operation

**Do not run installation during repository initialization.** Installing replaces Debian and destroys the selected internal disk. No remote success guarantee exists. Arrange physical access, a tested rescue USB, power and wired Ethernet before scheduling a maintenance window.

## Inventory and backup gate

In a later explicitly authorized inspection session, establish the host identity, SSH destination, working sudo/root path, UEFI versus BIOS, Secure Boot policy, internal drive persistent whole-disk ID, storage controller/initrd drivers, Ethernet interface, DHCP/static requirements, DNS, routes and firewall/NFS policy. Record public keys and verify their fingerprints. Inspect USB topology without modifying it; see storage.md.

Back up Debian configuration, partition information, NFS exports, UID/GID assignments and all Hermes state/credentials to an independent destination; test restoration. Account for databases requiring consistent application-level backups. Verify that loss of either USB drive is recoverable. Disconnect the USB drives for installation if operationally possible, after safely stopping consumers and unmounting them in a separately authorized maintenance procedure.

nixos-anywhere needs root SSH or supported passwordless sudo elevation to gain root. The installed system uses key-only `admin` SSH and passwordless sudo; root SSH is disabled. Arrange a temporary installer access path separately from installed access. Verify the selected upstream tool's `--help` before the maintenance window.

Kexec may be blocked by firmware lockdown/Secure Boot or unsupported hardware. The temporary environment may not inherit Debian's static addresses, Wi-Fi, VLAN, VPN, routes or DNS. Verify direct wired reachability and installer NIC support; do not rely exclusively on the Debian Tailscale session. Use a console/rescue installer when kexec or networking cannot be proven safe.

## Private configuration and validation

Copy `hosts/latitude/local.nix.example` into ignored `local/latitude.nix` and replace its deliberately failing assertion only after the inventory is complete. Configure the real internal disk, confirmed UEFI, initrd drivers, actual network and tested administrator keys. The supplied layout supports UEFI only, with GPT, 512 MiB ESP and ext4 root, no swap and no encryption. Revisit encryption or swap before installation if needed; legacy BIOS requires a reviewed alternative. No external device belongs in Disko.

Ignored files are omitted from Git flakes. Use an explicit local **path flake**, which includes ignored files in the Nix store: keep this checkout free of plaintext secrets and personal data. Preserve the private module independently for recovery.

```sh
nix flake check --no-update-lock-file
nix eval "path:$PWD#nixosConfigurations.latitude.config.system.build.toplevel.drvPath"
nix build "path:$PWD#nixosConfigurations.latitude.config.system.build.toplevel" --no-link
```

These evaluate/build only. Review the generated Disko configuration and dependencies; check that exactly one verified internal disk is selected. A persistent path is not proof of internal identity.

## Destructive future command

The following command is documentation only. Supply a verified target and run only under new explicit installation authorization, after all gates above. **It can destroy the selected system disk.**

```sh
: "${INSTALL_TARGET:?Set the verified root or sudo-capable installer SSH destination}"
nix run .#nixos-anywhere -- --flake "path:$PWD#latitude" --target-host "$INSTALL_TARGET"
```

The pinned nixos-anywhere drives kexec, Disko, installation and reboot. Watch the console; do not blindly retry after failure. After reboot verify installed `admin` SSH in a second session, sudo, routes, DNS, time, boot and firewall. Then inspect USB storage again before enabling mounts/exports. Restore services incrementally; do not enable agent scaffolds yet.

References: [upstream quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md), [Disko](https://github.com/nix-community/disko).
