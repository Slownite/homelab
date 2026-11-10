# Native NixOS containers

The example uses built-in `containers` backed by systemd-nspawn. Enable `homelab.exampleContainer.enable` in a reviewed configuration to create it; `autoStart = false` still requires a manual start. It runs a sandboxed sleep service, with no sensitive bind mounts, forwarded ports or devices. `privateNetwork = true` with no host/local address or bridge creates an isolated network namespace with loopback only. There is no internet connectivity or application listener. Future veth addressing, routing/NAT and DNS require a deliberate design after inventory; no private subnet is guessed here.

After a separately authorized deployment, on the server:

```sh
sudo nixos-container start example
sudo nixos-container stop example
sudo nixos-container root-login example
sudo journalctl -u container@example
sudo nixos-container run example -- journalctl -u demo
```

Native container root state normally persists under `/var/lib/nixos-containers/example`. Plan application-specific persistence and backup before enabling real applications; removing a definition is not a data migration plan. Never bind host root, SSH keys, NixOS secrets, NAS data or privileged sockets by default. Prefer dedicated unprivileged application identities.

The host container unit sets MemoryMax=256M, CPUQuota=25% and TasksMax=128. These are host cgroup limits, not disk quotas or a guarantee against all kernel resource exhaustion. Inspect effective cgroups and runtime behavior in later tests. The example is evaluated in CI but has not been run.

## Hermes

`homelab.hermes` is a production-shaped native container rather than an
example. It has a private veth with outbound NAT, no forwarded ports, a single
writable application-state bind mount, and host cgroup limits sized for Hermes.
It disables the gateway in Stage A and requires explicit Stage B activation
after state restoration. Its Nix daemon socket is hidden rather than exposed to
the agent. See [Hermes migration and operations](./hermes.md).

systemd-nspawn shares the host kernel and does not provide VM-level isolation. Command-executing agents need a threat-model review; use stronger isolation when untrusted workloads require it.
