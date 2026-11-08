# Storage preservation

The internal disk is the future OS disk and the sole Disko target. The two existing USB drives are external data storage; the audit confirms a healthy mdadm RAID1 with ext4. The private audited profile prepares assembly and mounting; the public generic configuration remains inactive.

In a later authorized read-only inspection session collect `lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS,MODEL,TRAN`, `findmnt`, `cat /proc/mdstat`, `cat /etc/fstab`, `cat /etc/exports`, `exportfs -v`, `id`, and relevant systemd mount/timer/service definitions. `sudo blkid` and `sudo mdadm --detail --scan` may help where installed. Inspect stable `/dev/disk/by-id` links and USB bridge behavior. Do not run array assembly, repair, fsck repair, synchronization, formatting or UUID-changing commands. Capture current sync scripts and schedules if present.

Record actual export paths, NFS versions, allowed clients, mount options, numeric owners/groups, ACLs and permissions, and Ubuntu's mount configuration. Preserve these semantics after migration. Recreate required numeric UID/GID mappings before serving data. Native `homelab.nfs` remains off; review explicit clients, `root_squash`, restrictive write permissions and version-specific scoped firewall rules before activation. Never use wildcard clients or `no_root_squash` by default.

Future mounts must use verified UUIDs or stable topology-appropriate identities. Do not put external disks in Disko. Decide failure behavior explicitly: an unavailable data disk should prevent consumers from starting. The NFS scaffold requires, orders after and binds to its declared mount and checks that it is mounted; mountPoint must refer to the actual mount unit, not an exported subdirectory.

Apply equivalent `RequiresMountsFor` plus an explicit mount unit dependency/`BindsTo` and `ConditionPathIsMountPoint` to future agents and backup jobs. A directory existing is insufficient: otherwise applications can write to an unmounted path on the OS disk. Verify failure and unplug behavior before production use.

Keep OS state, application state, NFS data and backup repositories distinct. Restic jobs are empty by default. Use runtime password/credential files via sops and least-privilege destination credentials. Define consistent database snapshots, retention, capacity alerts and independent/off-site destination. A USB mirror shares deletion/corruption risks and is not a backup. Do not call backups operational before completing and restoring a real backup; periodically test restoration and `restic check`.

## Audited existing RAID

`modules/storage/raid.nix` enables native `boot.swraid`, matching the existing array by UUID and name from the private inventory. It declares assembly only, never `mdadm --create`, Disko RAID content, member partitioning or formatting. `AUTO -all` inhibits automatic assembly of unlisted arrays. The existing filesystem mounts by its filesystem UUID, not `/dev/md0` enumeration. `noCheck` avoids automatic filesystem repair; `nofail` and a device timeout preserve SSH recovery if storage is unavailable. These options do not make mounting read-only or freeze RAID metadata once installed.

The exact export path, subnet, options and anonymous numeric IDs are preserved in the disabled private NFS settings. No account UID/GID has been inferred from the SSH username: verify existing 1000:1000 ownership and intended identities before exports. Future NFS activation needs client-scoped NFSv4 firewall rules; the current firewall exposes only SSH. Keep version 4.2 client compatibility. Verify `findmnt`, array member health and expected source UUID before enabling `homelab.nfs.enable`. Its mount-unit dependencies and mountpoint condition prevent exporting an underlying empty directory. Test mount-failure behavior before service use.

Native software RAID reference: [NixOS module](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/tasks/swraid.nix).

## Restored NFS service

The private deployment enables the preserved export for 192.168.8.0/24 with
the original squash IDs and options, plus the exports(5) `mountpoint` guard.
TCP 2049 is accepted only from that subnet; no global NFS port is opened.
NFSv3 and UDP are disabled; NFS 4.2 retains the existing absolute export path.

The server requires, orders after, and binds to the mount unit, with
RequiresMountsFor and ConditionPathIsMountPoint. Mount loss detected by systemd
stops the server; the export guard prevents exporting the underlying directory.
Hardware I/O failure can leave a filesystem mounted: these dependencies do not
detect every USB failure or guarantee uninterrupted service. No unplug test was
performed. After deployment verify exportfs, findmnt, service dependencies and
the existing Ubuntu NFS 4.2 client before considering restoration operational.
