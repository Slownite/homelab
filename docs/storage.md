# Storage preservation

The internal disk is the future OS disk and the sole Disko target. The two existing USB drives are external data storage; their approximate 4 TB usable capacity does not establish RAID or mirroring. No external mount is currently configured.

In a later authorized read-only inspection session collect `lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS,MODEL,TRAN`, `findmnt`, `cat /proc/mdstat`, `cat /etc/fstab`, `cat /etc/exports`, `exportfs -v`, `id`, and relevant systemd mount/timer/service definitions. `sudo blkid` and `sudo mdadm --detail --scan` may help where installed. Inspect stable `/dev/disk/by-id` links and USB bridge behavior. Do not run array assembly, repair, fsck repair, synchronization, formatting or UUID-changing commands. Capture current sync scripts and schedules if present.

Record actual export paths, NFS versions, allowed clients, mount options, numeric owners/groups, ACLs and permissions, and Ubuntu's mount configuration. Preserve these semantics after migration. Recreate required numeric UID/GID mappings before serving data. Native `homelab.nfs` remains off; review explicit clients, `root_squash`, restrictive write permissions and version-specific scoped firewall rules before activation. Never use wildcard clients or `no_root_squash` by default.

Future mounts must use verified UUIDs or stable topology-appropriate identities. Do not put external disks in Disko. Decide failure behavior explicitly: an unavailable data disk should prevent consumers from starting. The NFS scaffold requires, orders after and binds to its declared mount and checks that it is mounted; mountPoint must refer to the actual mount unit, not an exported subdirectory.

Apply equivalent `RequiresMountsFor` plus an explicit mount unit dependency/`BindsTo` and `ConditionPathIsMountPoint` to future agents and backup jobs. A directory existing is insufficient: otherwise applications can write to an unmounted path on the OS disk. Verify failure and unplug behavior before production use.

Keep OS state, application state, NFS data and backup repositories distinct. Restic jobs are empty by default. Use runtime password/credential files via sops and least-privilege destination credentials. Define consistent database snapshots, retention, capacity alerts and independent/off-site destination. A USB mirror shares deletion/corruption risks and is not a backup. Do not call backups operational before completing and restoring a real backup; periodically test restoration and `restic check`.
