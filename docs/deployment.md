# Normal deployment — future authorized operation

The root `justfile` provides manual shortcuts (install `just` on the workstation):

```sh
just check
just build latitude
just deploy-preview admin@verified-host latitude
just deploy-test admin@verified-host latitude
# After verifying a second SSH session and services:
just deploy admin@verified-host latitude
```

Replace the example SSH destination with the verified target; configure any
nonstandard deployment SSH port in your SSH client configuration. `deploy`
asks for confirmation. These recipes require the same explicit authorization
and checklist below. `check` validates only the public fixture; `build` uses
the private host. Neither refreshes the private flake lock automatically.

Provisioning uses nixos-anywhere once; normal configuration changes use the pinned `nixos-rebuild`. Disko partitioning is a separate destructive operation and is never part of routine deployment. Never run `switch` without an explicit remote target from Ubuntu.

First format, run `nix flake check --no-update-lock-file`, review the diff and private module, then evaluate and build as described in installation.md. Use the separate private flake described in installation.md, with a current lock and no plaintext credentials. Supply the verified installed admin SSH destination; do not infer it from the workstation.

Future authorized deployment example:

```sh
: "${DEPLOY_TARGET:?Set the verified admin SSH destination}"
nix run .#nixos-rebuild -- dry-activate --flake "path:$PWD/local#latitude" --target-host "$DEPLOY_TARGET" --sudo
nix run .#nixos-rebuild -- test --flake "path:$PWD/local#latitude" --target-host "$DEPLOY_TARGET" --sudo
# Verify a second SSH session, sudo, services, networking and storage before persistence.
nix run .#nixos-rebuild -- switch --flake "path:$PWD/local#latitude" --target-host "$DEPLOY_TARGET" --sudo
```

`test` changes the running remote system but does not set the next-boot default. It is not a sandbox and can immediately break access. `dry-activate` is a preview, not proof of safety. Keep the current SSH session and console access available. When changing access/network rules, arrange a separately tested timed rollback before activation. Do not remove the old access path until a second session works.

If still reachable, a future authorized rollback is `nix run .#nixos-rebuild -- switch --rollback --target-host "$DEPLOY_TARGET" --sudo`. If unreachable, use the console, reboot into the previous generation or rescue media; see recovery.md. Rollbacks do not revert application data, filesystem changes or secret rotation. Keep known-good generations; automatic garbage collection is off.

The server runs stock NixOS Nix. Ubuntu only evaluates/builds/copies and requests remote activation. CI never has deployment credentials and never activates anything. The pinned tool uses `--sudo` for remote privilege elevation. Verify flags with the pinned tool's help when updating the lock.
