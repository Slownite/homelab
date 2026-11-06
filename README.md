# Declarative NixOS homelab

Public infrastructure definitions for a headless Dell Latitude, developed on a separate Ubuntu workstation with Determinate Nix. **Phase 0 only: no server has been inspected, installed, or deployed.**

The target is x86_64-linux, an approximately seven-year-old Intel i7 laptop with 32 GB RAM, an internal system drive, and two external 4 TB USB drives providing approximately 4 TB usable storage. Their topology is unknown. External storage must survive migration intact.

```mermaid
flowchart LR
  Ubuntu[Ubuntu workstation] -->|manual SSH provisioning / deployment| Latitude[Latitude: NixOS stable]
  GitHub[Public GitHub: validation only] --> Repo[Pinned flake and modules]
  Repo --> Ubuntu
  Latitude --> Internal[Internal disk: Disko after inspection]
  Latitude --> USB[Existing USB storage: preserve]
  Latitude --> Containers[Native NixOS containers]
  Containers --> Agents[Future Hermes / PR-Agent]
```

## Architecture and status

NixOS 26.05 is the selected stable release ([official release](https://nixos.org/blog/announcements/2026/nixos-2605/)). Standard Nix from NixOS runs on the server; Determinate Nix is only a workstation tool. Flakes pin nixpkgs, Disko, sops-nix and nixos-anywhere. Small explicit modules configure systemd, networkd, SSH and firewall policy.

`nixosConfigurations.latitude` is the intended production host. Without ignored `local/latitude.nix`, its system build is a deliberate failing derivation. This allows flake inspection but prevents a successful build/install. With that file, assertions require disk selection, SSH keys and network configuration. These checks cannot prove that supplied hardware facts are correct.

CI separately evaluates non-deployable module fixtures, including the opt-in container. It never builds an installable validation system. Passing checks means module validation, **not deployment readiness**.

Implemented: stable locked flake, core system modules, SSH/firewall, conditional internal-disk UEFI/ext4 layout, sops integration, inactive storage/NFS/Restic/Tailscale scaffolds, offline example container, blocked agent integration points, local checks and CI.

Planned: actual hardware settings, storage mounts/exports, enrolled Tailscale, tested backups, monitoring, Hermes migration and verified PR-Agent packaging. No backups or services have been deployed.

## Layout

- `hosts/latitude/`: host composition, conditional Disko, hardware example.
- `modules/`: core, networking, storage, security and native containers.
- `services/`: fail-closed Hermes and PR-Agent integration points.
- `tests/`: non-deployable fixtures and policy/evaluation/format checks.
- `secrets/`: encrypted files only, after recipient setup.
- `docs/`: installation, deployment, storage, containers, security, recovery, architecture and ADRs.
- `.github/workflows/checks.yml`: validation without deployment.
- `local/`: ignored private hardware configuration; preserve separately.

## Development

```sh
git switch -c feature/describe-change
nix develop
nix fmt
nix flake check --no-update-lock-file
```

No system tool installation is required. Nix downloads pinned development/build dependencies into its store. Newly created source files must be visible to Git (`git add -N PATH`) for Git-flake evaluation. Review `git diff` and the public/private boundary before committing. Commit, open a PR, let CI validate, review and merge; deploy manually only in a later authorized task. No GitHub repository has been published.

Use [installation](docs/installation.md) for initial nixos-anywhere provisioning and [deployment](docs/deployment.md) for subsequent nixos-rebuild changes. Both run from Ubuntu and explicitly target the remote machine. Never activate NixOS on Ubuntu.

## Security and preservation

Key-only SSH and a firewall are configured. The dedicated `admin` key grants root-equivalent access through passwordless sudo; keep those keys tightly controlled. LAN SSH must be verified before restricting administration to Tailscale. No automatic Tailscale enrollment or public agent endpoint exists. Runtime secrets use sops-nix; plaintext, personal state and private hardware settings stay outside public history. See [security](docs/security.md).

Disko describes only one inspected internal drive. No USB device, mount or NFS export is activated. Storage consumers must depend on the real mount so failure cannot redirect writes into the system disk. A mirror is not an independent backup. See [storage](docs/storage.md).

## Roadmap

0. **Foundation:** flake, modules, Disko integration, provisioning docs, CI, secrets scaffold and container example (this repository).
1. **Physical installation:** inspect hardware/topology, back up data, fill private settings, test installation, install remotely, verify SSH and networking.
2. **Core infrastructure:** preserve USB mounts/NFS, enroll Tailscale, test independent Restic backup and restore, add monitoring.
3. **AI agents:** Hermes migration, on-demand PR-Agent, persistent state and isolation.
4. **Development infrastructure:** optional GitHub automation, runners, remote builder, binary cache and benchmarking.
5. **Experiments:** optional microvm.nix, sandboxed coding agents, agent evaluations and performance regression tests.
