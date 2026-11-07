# Initial installation — future authorized operation

**Do not run installation during repository initialization.** Installing replaces Debian and destroys the selected internal disk. No remote success guarantee exists. Arrange physical access, a tested rescue USB, power and wired Ethernet before scheduling a maintenance window.

## Inventory and backup gate

In a later explicitly authorized inspection session, establish the host identity, SSH destination, working sudo/root path, UEFI versus BIOS, Secure Boot policy, internal drive persistent whole-disk ID, storage controller/initrd drivers, Ethernet interface, DHCP/static requirements, DNS, routes and firewall/NFS policy. Record public keys and verify their fingerprints. Inspect USB topology without modifying it; see storage.md.

Back up Debian configuration, partition information, NFS exports, UID/GID assignments and all Hermes state/credentials to an independent destination; test restoration. Account for databases requiring consistent application-level backups. Verify that loss of either USB drive is recoverable. Disconnect the USB drives for installation if operationally possible, after safely stopping consumers and unmounting them in a separately authorized maintenance procedure.

nixos-anywhere needs root SSH or supported passwordless sudo elevation to gain root. The installed system uses key-only SSH for the administrator selected by `homelab.adminUser` and passwordless sudo; root SSH is disabled. Arrange a temporary installer access path separately from installed access. Verify the selected upstream tool's `--help` before the maintenance window.

Kexec may be blocked by firmware lockdown/Secure Boot or unsupported hardware. The temporary environment may not inherit Debian's static addresses, Wi-Fi, VLAN, VPN, routes or DNS. Verify direct wired reachability and installer NIC support; do not rely exclusively on the Debian Tailscale session. Use a console/rescue installer when kexec or networking cannot be proven safe.

## Private configuration and validation

Copy `hosts/latitude/local.nix.example` into ignored `local/latitude.nix` and replace its deliberately failing assertion only after the inventory is complete. Configure the real internal disk, confirmed UEFI, initrd drivers, actual network and tested administrator keys. The supplied layout supports UEFI only, with GPT, 1 GiB ESP, 16 GiB swap and remaining ext4 root, without encryption. Revisit encryption or swap before installation if needed; legacy BIOS requires a reviewed alternative. No external device belongs in Disko.

Ignored files are omitted from Git flakes (including dirty Git flakes). Keep the hardware profile private: its disk/RAID identifiers, username, public key comment, network and export settings would become public if committed. Private keys and credentials must never enter either flake or the Nix store.

Use a separate private flake. The prepared ignored `local/flake.nix` imports the public host module and adjacent `latitude.nix`. For a fresh checkout, copy `hosts/latitude/deployment-flake.nix.example` to `local/flake.nix` and set its homelab input to the public repository URL or `git+file:/absolute/path/to/homelab`. Preserve the private directory and its lock file independently. Use a path source for this small private directory only; it must contain no plaintext credentials or unrelated personal files.

From the public repository root:

```sh
nix fmt
nix flake check --no-update-lock-file
# Initially create the private lock; after public changes, refresh its homelab input:
nix flake update --flake "path:$PWD/local" homelab
nix eval --raw "path:$PWD/local#nixosConfigurations.latitude.config.system.build.toplevel.drvPath"
nix eval --json "path:$PWD/local#nixosConfigurations.latitude.config.disko.devices.disk" --apply 'disks: builtins.mapAttrs (_: d: { inherit (d) device; }) disks'
nix eval --raw "path:$PWD/local#nixosConfigurations.latitude.config.system.build.diskoScript.drvPath"
nix eval --json "path:$PWD/local#nixosConfigurations.latitude.config.services.openssh"
nix eval --json "path:$PWD/local#nixosConfigurations.latitude.config.networking.firewall"
nix eval --json "path:$PWD/local#nixosConfigurations.latitude.config.systemd.network.networks"
nix build "path:$PWD/local#nixosConfigurations.latitude.config.system.build.toplevel" --no-link
```

The public flake exports no `nixosConfigurations`: requesting a public host fails because the output is absent. It never imports ignored files. CI uses only the separate non-deployable validation fixture. The private system imports the same public host module, including the real Disko layout and prerequisite assertions; it does not import the validation fixture. Missing private files fail at import, and missing disk, keys, network or UEFI prerequisites fail the system toplevel evaluation. Evaluating individual options alone does not enforce every NixOS assertion.

These evaluate/build only. Review the generated Disko configuration and dependencies; check that exactly one verified internal disk is selected. A persistent path is not proof of internal identity.

## Destructive future command

The equivalent manual shortcut is
`just install admin@verified-host latitude 2222 22`, with arguments for the
verified installer destination, private host output, initial SSH port and
post-kexec SSH port. Replace all example values with audited settings.
The recipe asks for confirmation before running the destructive installer.
It does not create a hardware profile: another computer requires its own
reviewed private flake output and verified internal disk configuration.
All installation gates and explicit authorization requirements still apply.

The following command is documentation only. Supply a verified target and run only under new explicit installation authorization, after all gates above. **It can destroy the selected system disk.**

```sh
: "${INSTALL_TARGET:?Set the verified root or sudo-capable installer SSH destination}"
nix run .#nixos-anywhere -- --flake "path:$PWD/local#latitude" --target-host "$INSTALL_TARGET"
```

The pinned nixos-anywhere drives kexec, Disko, installation and reboot. Watch the console; do not blindly retry after failure. After reboot verify installed administrator SSH in a second session, sudo, routes, DNS, time, boot and firewall. Then inspect USB storage again before enabling mounts/exports. Restore services incrementally; do not enable agent scaffolds yet.

References: [upstream quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md), [Disko](https://github.com/nix-community/disko).

## Latitude 5300 audited preparation

UEFI and disabled Secure Boot are confirmed; Debian 13 is the current OS. Exact inventory/connection settings are in ignored `local/latitude.nix` and `local/latitude-notes.md`. The module is already prepared, so do not overwrite it with the generic example. Add the verified real administrator public key to its empty `homelab.adminKeys` list. Do not insert a private key. The key assertion intentionally blocks the production toplevel; static hardware and Disko evaluation can run before it is supplied.

Before granting installation authorization: confirm the exact whole-disk NVMe ID again, independently verify data/Hermes backup restoration, build the real system with the key, test the planned boot/network behavior, and arrange console/rescue access. The selected internal disk will be erased, including Debian's `/home` and Hermes virtual environment/state. Secure Boot being off does not prove kexec will succeed.

Use DHCP on the audited wired interface. Configure a DHCP reservation in the router for the existing address; no static address is configured by NixOS. Preserve SSH access on the audited port in the installed system and firewall. Debian passwordless sudo is available to the existing administrator; nixos-anywhere can elevate this session. Do not change Debian authentication during preparation.

### Three SSH stages

1. Debian uses its audited nonstandard SSH port and existing administrator account.
2. The kexec installer defaults to root SSH on **22**, independently of Debian's port; verify the actual image, network access and key transfer behavior beforehand. The pinned tool supports `--ssh-port` for the first connection and `--post-kexec-ssh-port` for this transition.
3. Installed NixOS uses the audited nonstandard port and key-only administrator account, with root SSH disabled. Verify its host key fingerprint at the console before accepting a changed host key; do not blindly remove host-key verification.

The private notes contain the concrete future command. **Do not execute it during preparation.** The earlier generic command must include appropriate port flags for this host.

After installation, verify RAID identity, both members, array health, filesystem UUID, mount source and numeric ownership before enabling any exports. Do not repair/recreate an array to make it match a name. A normal writable mount or RAID activation can update metadata; no such operation is performed by this task. NFS activation also requires scoped firewall review and a workstation NFS 4.2 mount test.

The pinned nixos-anywhere supports a local `--vm-test` without a target, but this task prohibits invoking nixos-anywhere. Its installation VM test is deferred until the real key is supplied and a separate VM-test run is authorized. Never pass a physical device through to an installation VM.

References: [SSH port and VM-test flags](https://github.com/nix-community/nixos-anywhere/blob/main/docs/reference.md).

## Local VM installation test

The private flake may expose `latitude-vm` using `latitude.extendModules` with
`homelab.nixosModules.installationVM` (see the deployment flake example).
Run `nix run .#nixos-anywhere -- --vm-test --flake "path:$PWD/local#latitude-vm"`.
Refresh the private homelab lock after committing public changes first.
This task authorizes this local VM test; the historical deferral above no longer applies.

The pinned Disko `makeDiskoTest` API supports `extraInstallerConfig`.
The test module uses it to force one 32768 MiB virtual disk instead of the
4096 MiB default. EFI remains 1 GiB, swap 16 GiB, and root uses the remainder.
Disko's test harness substitutes virtual device paths and tests the installed
system in QEMU. No physical device is passed through. The separate test output
changes only `system.build.installTest`; production partitioning, physical disk
identity, RAID configuration and prerequisite assertions remain unchanged.
Do not use a VM result as physical deployment readiness evidence.

Validation on Ubuntu, 2026-11-07: `nix fmt` and
`nix flake check --no-update-lock-file` passed. Private `local/validate.nix`
passed after refreshing the public input and updating its stale missing-key
expectation (the private profile now supplies a key). The command above passed
with exit code 0, including partitioning, installation into the virtual disk,
and booting the installed VM. No remote connection or physical storage operation
was performed. Physical deployment gates remain separate.
