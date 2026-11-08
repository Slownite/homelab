# Hermes native NixOS container

Hermes runs in the declarative `hermes` systemd-nspawn container. It uses the
upstream `hermes-agent.nixosModules.default` and its sealed package; upstream
OCI mode is explicitly disabled. Docker and Podman are not enabled.

The Hermes input retains its upstream-pinned nixpkgs rather than following the
host's `nixos-26.05`: the first host-nixpkgs build failed while applying its
`patchelf-0.15.2` patch. The upstream pin builds Hermes' sealed closure without
changing the host's NixOS package set. This Tier 2 compatibility exception is
intentional and must be retested whenever either lock input changes.

The host bind-mounts only `/var/lib/homelab/hermes` into the container at the
same path. Hermes's `stateDir` is that directory and its `HERMES_HOME` is
`/var/lib/homelab/hermes/.hermes`. The service identity is the container-only
system user and group `hermes` (UID/GID 992). The numeric identity makes bind
mount ownership stable across rebuilds without creating a host login user.

The container has a private veth (`10.231.136.2` through host
`10.231.136.1`), copied host DNS configuration, and host-side IPv4
masquerading. It has no forwarded ports. `container@hermes` starts at boot with
`MemoryHigh=5G`, `MemoryMax=6G`, `CPUQuota=300%`, and `TasksMax=512`.

## Isolation boundary

Hermes runs as an unprivileged identity inside the container. The only writable
host bind mount is its state directory. There are no NFS, host-root, display,
SSH, Docker/Podman, or container-management mounts or devices. The standard
NixOS-container Nix daemon bind is hidden by a private tmpfs; the container
uses the upstream sealed package and has `nix.enable = false`.

A native container shares the host kernel. Treat prompts, Discord messages,
MCP input, and skills as untrusted. This is process/filesystem isolation, not a
VM boundary. Do not add host paths, devices, sockets, `enableTun`, or OCI
container mode without a threat-model review.

## Stage A — infrastructure only

Add this to the private Latitude configuration, never the public repository:

```nix
{
  homelab.hermes = {
    enable = true;
    gateway.enable = false;
  };
}
```

Run local validation:

```sh
nix fmt
nix flake check --no-update-lock-file
nix build .#hermes-agent --no-link
just build latitude
```

Then use the separately authorized deployment flow:

```sh
: "${DEPLOY_TARGET:?set the verified Latitude administrator destination}"
just deploy-preview "$DEPLOY_TARGET" latitude 2222
just deploy-test "$DEPLOY_TARGET" latitude 2222
# Only after the deployment checklist and an explicit authorization:
just deploy "$DEPLOY_TARGET" latitude 2222
```

Stage A starts `container@hermes` but does **not** start `hermes-agent`; the
inner unit has no `WantedBy` target. It is safe to inspect the container and
networking without connecting Discord:

```sh
sudo systemctl status container@hermes
sudo nixos-container run hermes -- systemctl is-enabled hermes-agent
sudo nixos-container run hermes -- getent hosts discord.com
sudo nixos-container run hermes -- curl --fail --silent --show-error --head https://discord.com
sudo findmnt -R /var/lib/nixos-containers/hermes | grep -E 'homelab/hermes|nix/var/nix/daemon-socket'
```

The final command must show the dedicated state bind and must not show an
accessible Nix daemon socket. Do not print `.env`, `auth.json`, or any token
while validating.

## State migration and compatibility gate

Do not run these commands during repository initialization. They deliberately
require a deployed Stage A system, an explicit maintenance window, and the
backup paths supplied in the task. They never delete the workstation backup.

1. Stop the old Debian gateway before the Stage B activation. Never operate two
   Discord gateways with the same credentials.
2. Inventory the backup **before copying**. Identify the directory that was the
   old `~/.hermes`, any files referenced outside it, the source Hermes version,
   the CUA launch command, and the CUA driver version. Make a separately
   restorable archive of the exact source state; do not copy the Debian venv.
3. Transfer into a timestamped host-side staging directory. Substitute the
   verified target; this command intentionally has no `--delete`:

```sh
set -eu
stamp=$(date -u +%Y%m%dT%H%M%SZ)
target="$DEPLOY_TARGET"
source_home="$HOME/Backups/latitude/hermes" # inspect; do not assume its layout
ssh -p 2222 "$target" "sudo install -d -m 0700 -o root -g root /var/lib/homelab/hermes-import/$stamp"
rsync -aHAX --numeric-ids --protect-args --info=progress2 \
  --rsync-path='sudo rsync' -e 'ssh -p 2222' \
  "$source_home/" "$target:/var/lib/homelab/hermes-import/$stamp/"
```

4. On Latitude, make a restorable archive of the transferred staging tree,
   inspect it, and select the subdirectory that actually contains `config.yaml`,
   `auth.json`, memory, sessions, skills, MCP tokens, and other Hermes state.
   The name below is intentionally a placeholder selected from that inventory:

```sh
set -eu
stamp=REPLACE_WITH_THE_TRANSFER_TIMESTAMP
source_home=/var/lib/homelab/hermes-import/$stamp/REPLACE_WITH_INSPECTED_HERMES_HOME
sudo tar --acls --xattrs --numeric-owner -C "$(dirname "$source_home")" \
  -cpf "/var/lib/homelab/hermes-import/$stamp.pre-restore.tar" "$(basename "$source_home")"
sudo find /var/lib/homelab/hermes/.hermes -maxdepth 1 -printf '%f\n' | sort
```

5. The Stage A activation creates a Nix-managed empty skeleton. Preserve it
   rather than overwriting it, then restore only after the inspection confirms
   the selected source and the destination contains no prior migrated state:

```sh
set -eu
stamp=REPLACE_WITH_THE_TRANSFER_TIMESTAMP
source_home=/var/lib/homelab/hermes-import/$stamp/REPLACE_WITH_INSPECTED_HERMES_HOME
sudo mv /var/lib/homelab/hermes/.hermes "/var/lib/homelab/hermes/.hermes.stage-a.$stamp"
sudo install -d -m 0750 -o 992 -g 992 /var/lib/homelab/hermes/.hermes
sudo rsync -aHAX --numeric-ids --protect-args --chown=992:992 \
  "$source_home/" /var/lib/homelab/hermes/.hermes/
sudo chmod 0750 /var/lib/homelab/hermes /var/lib/homelab/hermes/.hermes
sudo find /var/lib/homelab/hermes/.hermes -type d -exec chmod 0750 {} +
sudo find /var/lib/homelab/hermes/.hermes -type f -exec chmod u=rw,g=,o= {} +
```

Do not use `hermes config migrate`. First run the pinned package's read-only
checks with the gateway still disabled:

```sh
sudo nixos-container run hermes -- sudo -u hermes env \
  HERMES_HOME=/var/lib/homelab/hermes/.hermes hermes config check
sudo nixos-container run hermes -- sudo -u hermes env \
  HERMES_HOME=/var/lib/homelab/hermes/.hermes hermes doctor
```

A non-zero result, an outdated/incompatible format report, unexpected file
write, or missing integration is a stop condition. Keep both archives, restore
the preserved Stage A skeleton if needed, and investigate against the pinned
Hermes revision. `doctor --live` is deliberately excluded because it makes
real provider/tool calls.

## Credentials and Discord

The restored `.env` and `auth.json` remain in the persistent state directory
with restrictive permissions. Hermes's NixOS module does not rewrite `.env`
when `environmentFiles` is empty, and it seeds `auth.json` only when an
`authFile` is explicitly configured. Thus the migration preserves runtime
credential refresh state.

After the migration is proven, credentials may be moved to the existing
sops-nix strategy in the ignored private configuration. Declare the encrypted
secret there, mount its runtime path read-only, and point the nested module at
it; never use `builtins.readFile` or a Nix string for a token:

```nix
{ config, ... }: {
  sops.secrets."hermes/env" = {
    sopsFile = ../secrets/hermes.enc.yaml;
    owner = "992";
    group = "992";
    mode = "0400";
  };
  containers.hermes.bindMounts."/run/secrets/hermes-env" = {
    hostPath = config.sops.secrets."hermes/env".path;
    isReadOnly = true;
  };
  containers.hermes.config.services.hermes-agent.environmentFiles = [
    "/run/secrets/hermes-env"
  ];
}
```

Use one credentials source at a time. Back up the current `.env` before
switching to sops. Never put Discord, provider, or MCP tokens in `settings`,
`environment`, logs, Git, or the Nix store.

## Stage B — explicit activation

Only after the compatibility gate, data inspection, and confirmation that the
Debian gateway is stopped:

```sh
sudo install -m 0600 -o root -g root /dev/null /var/lib/homelab/hermes/.gateway-enabled
```

Change the private configuration to `homelab.hermes.gateway.enable = true`,
then use the same reviewed deployment sequence from Stage A. The unit requires
both the declarative boolean and the marker; this prevents an accidental Stage
A gateway start. Verify without exposing tokens:

```sh
sudo nixos-container run hermes -- systemctl status hermes-agent --no-pager
sudo nixos-container run hermes -- journalctl -u hermes-agent -n 100 --no-pager
sudo nixos-container run hermes -- sudo -u hermes env \
  HERMES_HOME=/var/lib/homelab/hermes/.hermes hermes config check
```

Confirm Discord connection, expected memory/session/skills, and MCP state from
Hermes's redacted logs or Discord behavior. Then restart `container@hermes` and
repeat those checks to prove persistence. Do not dump configuration or use
unredacted CLI output in a terminal transcript.

## CUA Driver

The CUA Driver backup remains separate at
`~/Backups/latitude/cua-driver/`. Its version and MCP configuration are not
known to be compatible with the pinned Hermes release, and the server is
headless. Stage A and Stage B do not mount display sockets, browser profiles,
or host devices and do not enable CUA.

Preserve the CUA configuration in the staging archive. After Hermes is stable,
compare its version and MCP protocol with the pinned Hermes release in an
isolated test state. Either package a compatible driver as an explicit
container-local dependency or replace it with a supported headless MCP server.
Do not restore a browser profile or grant host display access merely to make
computer-use work.

## Service operations, upgrades, and rollback

```sh
sudo systemctl status container@hermes
sudo nixos-container run hermes -- systemctl status hermes-agent
sudo journalctl -u container@hermes -f
sudo nixos-container run hermes -- journalctl -u hermes-agent -f
sudo systemctl restart container@hermes
```

For an upgrade, stop the gateway, make a new ACL/xattr-preserving archive of
`/var/lib/homelab/hermes/.hermes`, update the pinned `hermes-agent` input,
review the lock diff, build the official package and private host, run checks,
and repeat `hermes config check` before re-enabling the service. Do not run
`hermes update`, pip, or npm against the Nix package.

A NixOS generation rollback only rolls back code/configuration, not state. If
a package or data migration fails, disable `gateway.enable`, remove the
root-owned activation marker, restore the pre-upgrade state archive into a new
inspected state directory, and deploy the prior reviewed generation. Keep the
source backup and every pre-migration archive until a tested restoration exists.
