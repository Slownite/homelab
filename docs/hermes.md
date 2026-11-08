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
same path. The native `hermes-agent` systemd service runs with
`HOME=/var/lib/homelab/hermes`, `HERMES_HOME=/var/lib/homelab/hermes/.hermes`,
and `WorkingDirectory=/var/lib/homelab/hermes/workspace`. The service identity
is the container-only system user and group `hermes` (UID/GID 992). The numeric
identity makes bind-mount ownership stable across rebuilds without creating a
host login user.

The container has a private veth (`10.231.136.2` through host
`10.231.136.1`), its own `systemd-resolved` stub, and Cloudflare upstream DNS
(`1.1.1.1`, `1.0.0.1`) reached through host-side IPv4 masquerading. It has no
forwarded ports. `container@hermes` starts at boot with `MemoryHigh=5G`,
`MemoryMax=6G`, `CPUQuota=300%`, and `TasksMax=512`.

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

## DNS and outbound-connectivity verification

The host's copied `resolv.conf` pointed the container at `127.0.0.53`, but
the container did not run a resolver at that loopback address. Hermes now owns
its resolver: `systemd-resolved` listens on the container-local stub and sends
queries to its declared upstreams through the existing `ve-hermes` IPv4
masquerade. `LinkLocalAddressing=no` prevents systemd-networkd from adding a
second automatic IPv4 link-local address beside `10.231.136.1`. No additional
NAT or inbound forwarding is configured.

Keep the Discord gateway stopped while checking DNS and egress:

```sh
sudo systemctl -M hermes is-active systemd-resolved
sudo systemd-run -M hermes --wait --pipe --collect \
  /run/current-system/sw/bin/getent ahostsv4 discord.com
sudo systemd-run -M hermes --wait --pipe --collect \
  /run/current-system/sw/bin/curl --fail --silent --show-error --head https://example.com
```

The final request proves outbound HTTPS without using Discord authentication.
Do not inspect Hermes credentials or start `hermes-agent` for these checks.

## State migration and compatibility gate

The original Debian restore is at the **stateDir root**. That is not Hermes's
runtime home under the pinned upstream NixOS module: it derives
`HERMES_HOME` as `$stateDir/.hermes`, creates that directory during activation,
and starts Hermes with that value. Therefore the generated
`/var/lib/homelab/hermes/.hermes` is expected; it lacks the restored `.env`
because the module has no `environmentFiles` configured. The gateway found no
platform configuration because it read that generated home, not the restored
root tree.

The following is the one-time, host-side correction for the already-deployed
container. It is intentionally fail-closed: it creates an ACL/xattr-preserving
archive before moving the generated home, copies only into a newly empty
`HERMES_HOME`, and writes a root-owned completion marker only after the copied
tree passes structural checks. A rerun after success exits without changing
state. A partial run has no marker and refuses to merge with its partial
destination; restore from the recorded archive or investigate first.

Do not run this during repository initialization. It requires the deployed
Stage A system and an explicit maintenance window. It neither contacts Discord
nor starts the gateway.

```sh
set -euo pipefail

state_dir=/var/lib/homelab/hermes
hermes_home="$state_dir/.hermes"
archive_dir=/var/lib/homelab/hermes-import
marker="$state_dir/.hermes-migration-v1"

# Do not alter state while a gateway could use it, and make success idempotent.
if sudo nixos-container run hermes -- systemctl is-active --quiet hermes-agent; then
  printf '%s\n' 'hermes-agent is active; stop it and investigate before migration' >&2
  exit 1
fi
if sudo test -e "$marker"; then
  printf '%s\n' "migration already completed; inspect $marker and do not rerun" >&2
  exit 0
fi

# Confirm this is the known root-layout restore without exposing its contents.
for path in config.yaml .env SOUL.md state.db memories sessions skills; do
  sudo test -e "$state_dir/$path" || {
    printf '%s\n' "missing expected restored state: $state_dir/$path" >&2
    exit 1
  }
done
sudo test -d "$hermes_home" || {
  printf '%s\n' "missing generated Hermes home: $hermes_home" >&2
  exit 1
}

stamp=$(date -u +%Y%m%dT%H%M%SZ)
archive="$archive_dir/hermes-pre-home-migration-$stamp.tar"
generated_home="$state_dir/.hermes.generated.$stamp"
sudo test ! -e "$archive"
sudo test ! -e "$generated_home"
sudo install -d -m 0700 -o root -g root "$archive_dir"

# Archive both independent trees before changing either. Do not inspect or
# print .env/auth contents.
sudo tar --acls --xattrs --numeric-owner -C "$(dirname "$state_dir")" \
  -cpf "$archive" "$(basename "$state_dir")"

# Never merge the generated state with the Debian restore.
sudo mv "$hermes_home" "$generated_home"
sudo install -d -m 2770 -o 992 -g 992 "$hermes_home"
sudo rsync -aHAX --numeric-ids --protect-args --chown=992:992 \
  --exclude='/.hermes' \
  --exclude='/.hermes.generated.*' \
  --exclude='/.hermes-migration-v1' \
  "$state_dir/" "$hermes_home/"

# Own and restrict only the new runtime home; retain every source file and the
# quarantined generated home unchanged.
sudo chown -R 992:992 "$hermes_home"
sudo chmod 2770 "$hermes_home"
sudo find "$hermes_home" -type d -exec chmod 2770 {} +
sudo find "$hermes_home" -type f -exec chmod u=rw,g=,o= {} +
sudo chmod 0640 "$hermes_home/.env"

for path in config.yaml .env SOUL.md state.db memories sessions skills; do
  sudo test -e "$hermes_home/$path" || {
    printf '%s\n' "copy verification failed: $hermes_home/$path" >&2
    exit 1
  }
done
printf 'archive=%s\ngenerated_home=%s\n' "$archive" "$generated_home" |
  sudo tee "$marker" >/dev/null
sudo chown root:root "$marker"
sudo chmod 0600 "$marker"
```

The original root layout remains intact as an additional recovery copy. The
generated home remains separately quarantined at the path recorded in the
marker. Do not delete either tree or merge files between them until the
migration has been validated.

Run the pinned package's non-network configuration checks with the gateway
still stopped. These commands set exactly the service environment without
printing credentials:

```sh
sudo nixos-container run hermes -- sudo -u hermes env \
  HOME=/var/lib/homelab/hermes \
  HERMES_HOME=/var/lib/homelab/hermes/.hermes \
  hermes config check
sudo nixos-container run hermes -- sudo -u hermes env \
  HOME=/var/lib/homelab/hermes \
  HERMES_HOME=/var/lib/homelab/hermes/.hermes \
  hermes doctor
```

A non-zero result, an outdated/incompatible format report, unexpected file
write, or missing integration is a stop condition. Keep the archive, source
tree, and quarantined generated home; remove no marker and do not activate
Discord.

## Credentials and Discord

The restored `.env` remains at `HERMES_HOME/.env` with mode `0640` and
ownership `992:992`. The upstream module does not rewrite `.env` when both
`environment` and `environmentFiles` are empty, and it seeds `auth.json` only
when an `authFile` is explicitly configured. Thus this migration preserves the
runtime Discord credential source without placing it in Git or the Nix store.

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
