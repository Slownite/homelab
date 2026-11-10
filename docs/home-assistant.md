# Home Assistant

## Definition of Done

### Scope

- User: Latitude LAN administrator.
- Interfaces: native NixOS `services.home-assistant`, Home Assistant web UI, ZHA onboarding flow, the Home Assistant Python environment, and the system firewall.
- Included: native Home Assistant Core, dependencies for the normal onboarding component set and ZHA, persistent local state, narrowly scoped serial access, LAN-only frontend access, and manual deployment/verification.
- Excluded: deployment or connection to Latitude, dongle firmware changes, public/remote exposure, Hermes/NAS/NFS/NAT changes, non-SQLite database configuration, and declarative Home Assistant UI configuration.

### The user must be able to

- [ ] DOD-01. Given the deployed Latitude configuration, when systemd reaches `multi-user.target`, then native `home-assistant.service` starts as the dedicated `hass` user and restarts after a failure.
- [ ] DOD-02. Given Home Assistant is running, when a LAN client opens `http://192.168.8.100:8123`, then it reaches the initial Home Assistant onboarding UI.
- [ ] DOD-03. Given onboarding is complete, when the user configures ZHA in the Home Assistant UI using the Sonoff stable serial path, then the packaged ZHA integration and its serial access prerequisites are available; the user verifies the radio type in that flow.
- [ ] DOD-04. Given the Home Assistant service environment, when `default_config` loads `dhcp`, `ssdp`, `stream`, and `go2rtc`, then their generated component dependencies, including `av` and `go2rtc_client`, import successfully.
- [ ] DOD-05. Given Home Assistant has UI-managed configuration and SQLite state, when the system is rebuilt or Home Assistant restarts, then that state remains in `/var/lib/home-assistant` and is not replaced by a Nix-store `configuration.yaml`.

### The user must not be able to

- [ ] DOD-06. Given a non-LAN source attempts TCP port 8123, when the packet reaches the Latitude firewall, then it is not accepted; no Home Assistant component ports are opened implicitly.
- [ ] DOD-07. Given Home Assistant is enabled, when it accesses devices, then systemd retains a closed device policy except for the NixOS module's serial-device allowance required by ZHA; unrelated device permissions are unchanged.
- [ ] DOD-08. Given this module is evaluated, then Hermes, NAT, NFS, SSH, and NAS configuration are unchanged.

### Persistence and recovery

- [ ] DOD-09. Given Home Assistant fails, then systemd restarts it; its configuration directory remains local persistent host state across NixOS generations and rebuilds.

### Evidence

- DOD-01, DOD-03, DOD-06, DOD-07, DOD-08, DOD-09. Focused NixOS module-evaluation check.
- DOD-04. Focused Nix build imports the generated dependency packages from the configured Home Assistant Python path.
- DOD-02, DOD-05. Authorized post-deployment service, socket, firewall, and restart verification steps below.

## Reconciliation

- DOD-04, DOD-07, DOD-08: PASS — `nix flake check --no-update-lock-file` runs the import and focused module-evaluation assertions.
- DOD-01, DOD-02, DOD-03, DOD-05, DOD-06, DOD-09: BLOCKED — require an authorized Latitude deployment and LAN/on-host verification.


## Deployment

Do not deploy from the workstation without separate authorization. First review the generated configuration and complete the standard deployment prerequisites in [deployment.md](deployment.md).

```sh
: "${DEPLOY_TARGET:?Set the verified admin SSH destination}"
export NIX_SSHOPTS="${NIX_SSHOPTS:+$NIX_SSHOPTS }-p 2222"
nix run .#nixos-rebuild -- dry-activate --flake "path:$PWD/local#latitude" --target-host "$DEPLOY_TARGET" --sudo
nix run .#nixos-rebuild -- test --flake "path:$PWD/local#latitude" --target-host "$DEPLOY_TARGET" --sudo
# Keep the existing SSH session open; inspect the checks below before any authorized switch.
```

`test` changes the running remote system and requires explicit authorization. It is not part of this change.

## Post-deployment verification

From a LAN client, open `http://192.168.8.100:8123` and complete onboarding. In **Settings → Devices & services → Add integration → Zigbee Home Automation**, select the stable path:

```text
/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_167f1800b812ef11801a75b8bf9df066-if00-port0
```

Do not choose a radio type from the USB `cp210x` bridge alone. Let ZHA probe it, or use its diagnostic/error output to confirm the appropriate radio type for the installed dongle. Do not flash firmware.

On the authorized target, verify the service, its serial-device policy, and persistent local state without restarting it:

```sh
sudo systemctl is-enabled home-assistant.service
sudo systemctl is-active home-assistant.service
sudo systemctl show home-assistant.service --property=User,Group,Restart,DevicePolicy,DeviceAllow,SupplementaryGroups
sudo runuser -u hass -g hass -G dialout -- test -rw /dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_167f1800b812ef11801a75b8bf9df066-if00-port0
sudo journalctl -u home-assistant.service -b --no-pager | grep -E 'ModuleNotFoundError|Setup failed|Could not setup dependencies' && exit 1 || true
sudo ls -ld /var/lib/home-assistant
sudo ls -l /var/lib/home-assistant/home-assistant_v2.db
```

Run a restart/recovery test only under separate authorization; it is not part of deployment verification.

From a LAN client, verify the frontend:

```sh
curl --fail http://192.168.8.100:8123/
```

Verify port 8123 is rejected from a non-LAN network using an authorized test host. Do not use an Internet scan. Confirm no unexpected listener was added:

```sh
sudo ss -ltnp
```

The configuration intentionally leaves `services.home-assistant.config = null`: Home Assistant creates and owns `configuration.yaml` and its SQLite database in `/var/lib/home-assistant`. That directory is on the Latitude system disk, not `/mnt/external_data`.
