# Caddy reverse proxy

## Definition of Done

### Scope

- User: Latitude LAN administrator and Home Assistant browser clients.
- Interfaces: native NixOS `services.caddy`, `https://home.home.arpa`, Home Assistant's runtime-managed `configuration.yaml`, system firewall, and Caddy's persistent local PKI storage.
- Included: a reusable native Caddy virtual-host module, TLS from Caddy's internal CA, a loopback Home Assistant upstream, LAN-scoped HTTPS, and operational instructions for trust, deployment, and verification.
- Excluded: deployment, a connection to Latitude, OpenWrt or DNS changes, any public exposure or port forwarding, replacement of Home Assistant state, and HTTP-to-HTTPS redirection.

### The user must be able to

- [ ] DOD-01. Given Latitude starts, when systemd reaches `multi-user.target`, then `caddy.service` is enabled and starts with the configured virtual host for `home.home.arpa`.
- [ ] DOD-02. Given a LAN client trusts Caddy's root CA and resolves `home.home.arpa` to Latitude, when it requests `https://home.home.arpa`, then Caddy presents an internally issued certificate and proxies the request to Home Assistant at `127.0.0.1:8123`.
- [ ] DOD-03. Given Home Assistant's runtime-managed `configuration.yaml` contains the documented `http` integration that trusts only `127.0.0.1`, when Caddy proxies HTTP and WebSocket requests, then Home Assistant accepts that loopback reverse proxy and its WebSocket endpoint upgrades successfully.
- [ ] DOD-04. Given Caddy has generated its local CA, when Caddy or Latitude restarts, then the root certificate and private signing key remain in persistent Caddy state and the existing root certificate is retained.
- [ ] DOD-05. Given an administrator needs to trust clients, when they follow the documented retrieval instructions, then they obtain only Caddy's public root certificate and can install it on Ubuntu and Firefox.

### The user must not be able to

- [ ] DOD-06. Given a TCP connection reaches `eno2` from outside `192.168.8.0/24`, when it targets port 443, then the firewall does not accept it.
- [ ] DOD-07. Given a LAN client targets TCP port 80, when it reaches Latitude, then no HTTP redirect listener is exposed.
- [ ] DOD-08. Given a LAN client targets Caddy's administration port, when it reaches Latitude, then it cannot connect because the administration API is bound only to loopback.
- [ ] DOD-09. Given a LAN client targets Home Assistant's TCP port 8123, when it reaches Latitude, then the firewall does not accept it; SSH, NFS, NAT, Hermes networking, OpenWrt, and Home Assistant onboarding/state are unchanged.

### Persistence and recovery

- [ ] DOD-10. Caddy's `$HOME/.local/share/caddy`, including `pki/authorities/local`, is backed by the persistent `/var/lib/caddy` service state; the root key is never copied into the Nix store or documentation.
- [ ] DOD-11. Given the administrator has merged the documented `http` integration into the existing `/var/lib/home-assistant/configuration.yaml`, when Home Assistant is rebuilt or Latitude reboots, then the file and its loopback-only proxy trust remain present.

### Evidence

- DOD-01, DOD-06–DOD-10. Focused NixOS module-evaluation assertions and `nix flake check --no-update-lock-file`.
- DOD-02–DOD-05. Authorized post-deployment LAN and on-host commands below.

## Deployment

Do not deploy from the workstation without separate authorization. Home Assistant's
NixOS module intentionally sets `services.home-assistant.config = null`, so
`/var/lib/home-assistant/configuration.yaml` remains runtime-managed persistent
state. On the authorized target, edit that existing file in place; do not replace
it or the SQLite database.

Merge this into its existing top-level `http:` mapping, or add this one top-level
mapping only when it has none:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```

Caddy's only upstream is `127.0.0.1:8123`; `127.0.0.1` is therefore the sole
trusted proxy. Do not add `::1`, a LAN address, or a subnet. Do not create a
second top-level `http:` key.

Check the merged configuration before restarting Home Assistant:

```sh
sudo -u hass /run/current-system/sw/bin/hass --config /var/lib/home-assistant --script check_config
sudo systemctl restart home-assistant.service
sudo systemctl is-active home-assistant.service
```

The completed configuration intentionally has no LAN firewall exception for TCP 8123. Caddy reaches Home Assistant over loopback, so this does not affect the proxy.

## Root CA retrieval and client trust

Caddy runs as `caddy` with persistent home `/var/lib/caddy`; its default file storage therefore holds the public root at:

```text
/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
```

On Latitude, copy only that public certificate to a controlled transfer path. Never copy `root.key`, `intermediate.key`, the containing PKI directory, or any Caddy private key.

```sh
sudo install -m 0644 -o "$USER" -g "$USER" \
  /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt \
  ./caddy-local-root.crt
```

On an Ubuntu client, install the copied public certificate into the system trust store:

```sh
sudo install -m 0644 ./caddy-local-root.crt /usr/local/share/ca-certificates/caddy-local-root.crt
sudo update-ca-certificates
```

For Firefox, open **Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import**, select `caddy-local-root.crt`, and allow it to identify websites. Firefox may use its own certificate store; the system-store installation alone is not sufficient in that configuration.

## Authorized post-deployment verification

Run these only after an authorized deployment; they do not connect to Latitude from the workstation automatically.

On Latitude:

```sh
sudo systemctl is-enabled caddy.service
sudo systemctl is-active caddy.service
sudo systemctl show caddy.service --property=User,Group,StateDirectory,Restart
sudo ss -ltnp '( sport = :443 or sport = :80 or sport = :2019 )'
sudo iptables -C nixos-fw -i eno2 -s 192.168.8.0/24 -p tcp --dport 443 -j nixos-fw-accept
sudo journalctl -u caddy.service -b --no-pager
sudo test -r /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
sudo sha256sum /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt
```

From a trusted LAN client after installing the root CA:

```sh
getent ahostsv4 home.home.arpa
curl --fail --cacert ./caddy-local-root.crt https://home.home.arpa/
curl --fail --cacert ./caddy-local-root.crt --http1.1 \
  --include --no-buffer \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  https://home.home.arpa/api/websocket
```

`getent` must report `192.168.8.100`; the second `curl` command must receive
`101 Switching Protocols` after Home Assistant is configured and running. Also
complete an interactive browser login and observe the Home Assistant UI remain
connected.

From an authorized non-LAN test host, verify `192.168.8.100:443` is rejected; do not scan from the Internet. From a LAN client, verify TCP 8123 is no longer accepted:

```sh
nc -zvw 3 192.168.8.100 8123 && exit 1 || true
```

The `nc` command must fail from a LAN client. On Latitude, confirm the policy and
that the only Caddy administration listener is loopback:

```sh
sudo iptables -C nixos-fw -i eno2 -s 192.168.8.0/24 -p tcp --dport 443 -j nixos-fw-accept
sudo iptables -S nixos-fw | grep -- '--dport 8123' && exit 1 || true
sudo ss -ltnp '( sport = :2019 or sport = :8123 )'
sudo test "$(stat -c %a /var/lib/caddy)" = 700
```

## Backup and restore Caddy state

`/var/lib/caddy/.local/share/caddy` contains the internal CA, issued
certificates, and private keys. It is persistent service state, not a
Nix-generated directory. Back it up only to encrypted, access-controlled
storage; preserve numeric ownership and permissions. Do not add the archive or
any private key to Git.

For a consistent backup, schedule a short Caddy outage, stop the service, and
archive its data directory. Replace `/secure/backup` with a protected backup
mount that is not this repository or the NAS automatically managed by this
flake.

```sh
sudo systemctl stop caddy.service
sudo install -d -m 0700 -o root -g root /secure/backup
sudo tar --xattrs --acls --numeric-owner -C /var/lib/caddy \
  -czf /secure/backup/caddy-state-$(date +%F).tar.gz .
sudo systemctl start caddy.service
sudo systemctl is-active caddy.service
```

To restore after stopping Caddy, retain the failed directory for forensics,
extract the archive into a newly created `/var/lib/caddy`, and restore its
ownership/mode from the archive before starting Caddy. Test a copy in an
isolated path first. Never restore only `root.crt`: the matching private key
and issued certificate state must remain consistent.

For persistence, record the displayed root-certificate digest, reboot only under separate authorization, then repeat the on-host `sha256sum` and HTTPS checks. The digest must be unchanged. Finally, inspect existing service status and listeners to confirm no unrelated service regressed:

```sh
sudo systemctl --failed
sudo systemctl is-active home-assistant.service
sudo ss -ltnp
```

## Reconciliation

- DOD-01, DOD-06–DOD-10: PASS — focused NixOS evaluation assertions and `nix flake check --no-update-lock-file`.
- DOD-02–DOD-05, DOD-11: BLOCKED — require an authorized Latitude deployment plus LAN/on-host verification.
