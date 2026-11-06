# Recovery runbook — prepare before installation

Keep local console access, tested rescue media, independent data backups, private hardware configuration, age recovery keys and a known-good NixOS generation. Avoid unattended upgrades and garbage collection until recovery is proven.

For a failed remote activation, use the still-open SSH session to inspect systemd/journal state and roll back with the explicitly remote command in deployment.md. A `test` activation normally returns to the saved generation on reboot; verify boot-generation behavior before relying on it. If access is lost, use the console and select the prior generation in systemd-boot. A failed boot may require rescue media and a reviewed manual mount/chroot recovery procedure using the verified internal disk. Never rerun Disko as a boot-repair shortcut.

Recover networking before changing services. Check actual interface naming, networkd leases/routes, firewall, SSH keys and sudo. Restoring an old generation does not restore deleted data, databases, credentials or firmware variables.

For USB failures stop writers and preserve evidence/topology. Do not initialize, recreate or blindly assemble arrays; determine the existing implementation first and recover from independent backups or a reviewed storage-specific procedure. Avoid mounting uncertain filesystems read-write.

Restore the host age identity securely before starting secret-dependent services; verify decryptions without printing values. Restore application data to the correct mounted destination with original numeric ownership and consistent database recovery. Test a restore to an isolated destination before replacing live state. If keys are lost without a backup, reissue upstream credentials rather than claiming SOPS can recover them.
