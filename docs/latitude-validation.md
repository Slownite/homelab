# Latitude 5300 preparation validation

Executed on the Ubuntu development workstation, 2026-11-07. No Latitude connection, physical Disko execution, installation, remote deployment or operating-system change was performed. Flake inputs remain unchanged.

- `nix fmt` and `nix fmt -- local/latitude.nix local/validate.nix`: passed.
- `nix flake check --no-update-lock-file`: passed formatting and module checks, including non-deployable RAID assembly/mount policy fixtures, disabled-by-default services, container evaluation and NFS mount guards.
- `nix eval --impure --json --file local/validate.nix`: passed against the actual ignored hardware profile. Checks cover the exact internal NVMe and sole Disko disk, ESP/swap/ext4 layout, installed SSH/firewall port, wired DHCP, enabled software RAID, UUID mount, disabled NFS, enabled-NFS mount dependencies and the exact remaining failed host assertion. The generated Disko script derivation evaluates; it was not built or executed.
- `nix eval --raw "path:$PWD#nixosConfigurations.latitude.config.system.build.toplevel.drvPath"`: intentionally fails with `Verified administrator keys required`. No real public key was supplied and none was invented. All other evaluated host assertions passed.
- `git diff --check`: passed.
- `git check-ignore local/latitude.nix local/latitude-notes.md local/validate.nix`: confirms private inventory and test data stay outside Git.

The pinned nixos-anywhere source supports `--vm-test`, and `/dev/kvm` is readable/writable. No installation VM test was executed: this task explicitly prohibits executing nixos-anywhere, and the real-key production build gate remains unmet. No live container, system closure, boot or remote connectivity test is claimed. CI itself has not run on GitHub.

## Remaining blockers

1. Insert and verify the real administrator public key in ignored `local/latitude.nix` (`homelab.adminKeys`), then evaluate/build the production system and perform a separately authorized safe installation VM test without physical-device passthrough.
2. Verify independent, consistent backups and restore tests for Debian configuration, Hermes/CUA state, credentials and important RAID data. The mirror alone is insufficient.
3. Reconfirm the internal NVMe identity immediately before the destructive operation; arrange console/rescue access and power. Verify firmware boot path and required initrd drivers with a real generated hardware report or installer test.
4. Reserve the audited DHCP address on the router; verify wired DHCP and the Debian-to-installer SSH port/key transition. Preserve existing recovery access until verified key-based administration works.
5. After installation, verify array member health, filesystem identity, mount source and ownership before enabling NFS. Verify numeric 1000:1000 mappings, client-scoped firewall rules and NFS 4.2 workstation compatibility. Neither current NFS service nor workstation mounts have changed.
6. Obtain new explicit installation authorization. Hermes packaging/runtime/container isolation and restore procedure remain a later migration task.

Exact disk/network identifiers and command examples are in ignored `local/latitude-notes.md`; preserve that directory separately. The public repository remains a sanitized foundation and cannot reproduce this specific machine without its private profile.
