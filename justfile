set shell := ["bash", "-euo", "pipefail", "-c"]

# List available commands without changing any system.
default:
    @just --list

# Format and validate the public configuration (not deployment readiness).
check:
    nix fmt
    nix flake check --no-update-lock-file

# Build a private host without activating it; refresh its lock separately.
build host="latitude":
    nix build "path:$PWD/local#nixosConfigurations.{{host}}.config.system.build.toplevel" --no-link

# Preview remote activation. Requires explicit deployment authorization.
deploy-preview target host="latitude":
    test -n "{{target}}"
    nix run .#nixos-rebuild -- dry-activate --flake "path:$PWD/local#{{host}}" --target-host "{{target}}" --sudo

# Activate temporarily; verify access and services before running deploy.
deploy-test target host="latitude":
    test -n "{{target}}"
    nix run .#nixos-rebuild -- test --flake "path:$PWD/local#{{host}}" --target-host "{{target}}" --sudo

# Persist remote activation after the deployment checklist and test.
[confirm("Persist configuration on the specified remote target?")]
deploy target host="latitude":
    test -n "{{target}}"
    nix run .#nixos-rebuild -- switch --flake "path:$PWD/local#{{host}}" --target-host "{{target}}" --sudo

# DESTRUCTIVE: complete docs/installation.md and verify the internal disk first.
# Port parameters cover the initial SSH connection and the kexec installer.
[confirm("ERASE the configured internal disk and install the specified remote computer?")]
install target host="latitude" ssh_port="22" installer_port="22":
    test -n "{{target}}"
    nix run .#nixos-anywhere -- --flake "path:$PWD/local#{{host}}" --target-host "{{target}}" --ssh-port "{{ssh_port}}" --post-kexec-ssh-port "{{installer_port}}"
