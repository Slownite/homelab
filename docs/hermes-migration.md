# Hermes migration to a native NixOS container

## Definition of Done

### Scope

- User: the Latitude administrator restoring the existing Hermes Discord gateway.
- Interfaces: the `homelab.hermes` NixOS module, `container@hermes`, the
  persistent state tree, the private secret configuration, and the documented
  migration and activation commands.
- Included: a systemd-nspawn NixOS container running the upstream Hermes NixOS
  module and official package, isolated egress networking, a bind-mounted
  persistent state directory, and an explicit two-stage migration.
- Excluded: deployment, backup transfer, production gateway activation, Disko,
  RAID, NFS, host-network changes, Docker/Podman, host display access, and
  computer-use enablement.

### The user must be able to

- [ ] DOD-01. Given `homelab.hermes.enable = true` and
  `homelab.hermes.gateway.enable = false`, when the host is deployed, then a
  `hermes` NixOS container starts automatically but its Discord gateway remains
  stopped.
- [ ] DOD-02. Given the Stage A container, when Hermes state is restored to
  `/var/lib/homelab/hermes`, then its `HERMES_HOME` is
  `/var/lib/homelab/hermes/.hermes` and survives a container restart, rebuild,
  host reboot, and package upgrade.
- [ ] DOD-03. Given an inspected compatible backup and a separately copied
  restorable source archive, when the administrator follows Stage B, then the
  gateway starts under its dedicated unprivileged `hermes` identity with the
  prior memory, sessions, skills, identity, configuration, credentials, Discord
  authentication, and MCP state intact.
- [ ] DOD-04. Given the Stage A container, when the administrator inspects
  networking, then it has outbound DNS and HTTPS connectivity without an
  application listener or host port forwarding.

### The user must not be able to

- [ ] DOD-05. Given a running Hermes container, when Hermes executes as its
  service identity, then it has no host root, NFS, display, Docker/Podman, Nix
  daemon, SSH, or container-management socket mount.
- [ ] DOD-06. Given the public repository and Nix store, when it is inspected,
  then neither backup contents nor plaintext provider, Discord, or MCP
  credentials are present.
- [ ] DOD-07. Given the previous CUA Driver configuration, when Stage A is
  deployed, then CUA remains preserved but disabled pending a headless
  compatibility review.

### Persistence and recovery

- [ ] DOD-08. A failed compatibility check, transfer, or activation leaves the
  source backup unchanged, does not replace existing destination state, and
  leaves the gateway disabled.

### Evidence

- DOD-01/DOD-04/DOD-05: evaluate the enabled validation fixture and inspect
  its declared container, systemd, network, and bind-mount configuration.
- DOD-02/DOD-03/DOD-06/DOD-07/DOD-08: inspect the staged migration procedure
  and run its preflight-only local checks; production-state restoration and
  Discord connectivity require separately authorized deployment.

### Reconciliation

- DOD-01. BLOCKED — enabled fixture evaluation proves the Stage A unit has
  `autoStart = true` and no gateway `WantedBy`; the prohibited deployment is
  the remaining live proof.
- DOD-02. BLOCKED — the state path and bind mount evaluate, but restart,
  rebuild, reboot, and upgrade persistence require a deployed container.
- DOD-03. BLOCKED — backup compatibility and Discord activation require the
  explicitly prohibited backup transfer and production activation.
- DOD-04. BLOCKED — private veth, host DNS, masquerading, and no forwarded
  ports evaluate; live DNS/HTTPS proof requires deployment.
- DOD-05. BLOCKED — evaluation proves the only declared writable bind is state,
  OCI mode is disabled, and the Nix daemon path is hidden; runtime mount
  inspection requires deployment.
- DOD-06. PASS — no backup or credential data was accessed or introduced, and
  secret references are runtime paths in the documented private configuration.
- DOD-07. BLOCKED — CUA is deliberately unconfigured; its preserved backup
  layout and compatibility require the prohibited backup inspection.
- DOD-08. PASS — the documented transfer stages into a timestamped directory,
  archives it before restoration, preserves the Stage A skeleton, and has no
  delete or overwrite operation.

Local evidence: `nix fmt`, enabled fixture evaluation,
`nix flake check --no-update-lock-file`, `nix build .#hermes-agent --no-link`,
and `nix run .#hermes-agent -- --version` passed. The original host-nixpkgs
package build failed at its `patchelf-0.15.2` patch; retaining upstream's
pinned nixpkgs was the compatibility adjustment, after which the official
package built and ran.

## Migration procedure

Stage A and Stage B, including exact commands, compatibility gates, CUA
limitations, operations, upgrades, and rollback are documented in
[`docs/hermes.md`](./hermes.md). The backup remains untouched until that
procedure is explicitly run after a deployed Stage A container has passed its
preflight checks.
