# Architecture

The workstation is a development client, never the installation target. The remote Latitude owns production services. Modules use native NixOS options, avoiding an orchestration framework. `system.stateVersion` starts at 26.05 and is not changed merely when upgrading nixpkgs.

See [ADR 0001](adr/0001-private-hardware-and-validation-boundary.md) and [glossary](../GLOSSARY.md) for the accepted public/private boundary. A private hardware module is not a secret store: Nix imports are copied into the world-readable Nix store. Keep credentials out even when a source file is Git-ignored.

The production system build is blocked without private hardware configuration. Validation intentionally never realizes a system toplevel; its fixture includes an unconditional false assertion to prevent installation. Checks evaluate actual module values and enabled container configuration. They do not prove bootability, firmware compatibility, remote networking or runtime isolation. A future VM test may add runtime coverage without touching physical disks.

No generic service framework is introduced. Hermes and PR-Agent have explicit blocked enable options; native Restic settings can be supplied through `homelab.backupJobs` after review.
