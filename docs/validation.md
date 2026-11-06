# Foundation validation record

Executed locally on the Ubuntu workstation with Determinate Nix 3.24.2 (Nix 2.35.3), during repository initialization, 2026-11-07.

- `nix eval --expr '1 + 1'`: passed, returned `2`.
- `nix flake lock`: succeeded; stable nixpkgs, Disko, sops-nix, nixos-anywhere and transitive inputs are pinned.
- `nix fmt`: passed after adding the repository formatter wrapper.
- `nix flake check --no-update-lock-file`: passed. Formatting and module evaluation checks succeeded; enabled native container configuration and enabled synthetic NFS mount guards were evaluated. Host/container assertions are checked except the intentional non-deployable validation-fixture assertion.
- `git diff --check`: passed.
- `nix build .#nixosConfigurations.latitude.config.system.build.toplevel --no-link`: failed as expected, with `Deployment blocked: provide inspected local/latitude.nix via path flake`. This builds only a deliberate failing sentinel, not a server system.

Initial checks exposed formatter invocation, read-only NixOS output, fixture resolver and NFS utility issues; these were corrected before the final passing run.

No NixOS system closure, live container, boot image or VM installation was built/tested. The example's runtime isolation/resource enforcement remains unverified. CI configuration is written and action revisions pinned, but GitHub Actions has not run. No server connection, Disko execution, installation, deployment, data migration, secret generation or public repository creation occurred.

Before installation obtain verified internal whole-disk identity, firmware/boot and Secure Boot policy, drivers, wired network configuration, administrator keys, console recovery, USB filesystem/array/sync topology, NFS semantics and ownership, and a tested independent backup of Debian/Hermes/data. Decide encryption/swap needs and confirm the UEFI layout is appropriate. Resolve exact Hermes and PR-Agent upstream versions, runtime packaging and persistence separately before enabling them.
