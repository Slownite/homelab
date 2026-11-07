# Hermes preinstallation backup and future integration

The audit identifies a Debian systemd **user** service using a Python virtual environment under the user's Hermes state directory, running `python -m hermes_cli.main gateway run`. Exact home/service/executable paths belong in ignored `local/latitude-notes.md`. No Hermes installation, migration or packaging is implemented. `homelab.hermes.enable` remains blocked.

Before erasing Debian, independently back up and test restoration of:

- The complete Hermes state tree: memory, sessions, skills, configuration, credentials, databases, attachments, logs and any other persistent files discovered during inventory.
- The user unit, all drop-ins, environment files, launch wrappers, user-systemd environment, lingering configuration, timers and dependencies.
- The Hermes source revision, local modifications, Python version, package/dependency lock information and external OS/runtime dependencies. Preserve the venv as evidence, but rebuild dependencies for NixOS; copied Debian executables/venvs may reference unavailable loaders, paths and libraries.
- CUA Driver MCP source/version, launch configuration, credentials, browser/profile/session data, dependent services, state outside the Hermes directory and any required display/browser/device capabilities.
- Numeric file ownership, modes, ACLs and symlink destinations; inspect references to data outside the main tree. Back up those targets explicitly.

Arrange a separately authorized consistent backup window: stopping the gateway alone may leave MCP child processes or databases running. Do not archive live state blindly; verify application/database consistency and test restoration in an isolated location. Protect credentials and personal memory outside Git and the Nix store.

The eventual native container needs its own package/runtime, persistent state and runtime secret paths, unprivileged identity, explicit egress and CUA isolation design. No host root, host shell, private NAS or privileged socket mounts by default. Resolve whether CUA can be isolated adequately in nspawn; it shares the host kernel.

Measured memory is roughly 1.8 GiB typical and 4.6 GiB historical peak. The example container's 256 MiB limit is unsuitable for Hermes. Derive and test a dedicated memory limit with headroom, CPU/task limits and behavior under OOM, including CUA usage; do not enable Hermes by copying the example.
