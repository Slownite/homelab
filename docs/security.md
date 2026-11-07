# Security and secrets

The public repository contains no production credentials. Keep private hardware data, age/SSH private keys, tokens, passwords, personal documents, Hermes memory/sessions/configuration and plaintext exports out of Git. Git ignore rules are a convenience, not a secret scanner. Review staged content before publishing. If a credential reaches public history, revoke/rotate it immediately; deleting the file does not retract it.

## age and sops-nix

Generate keys only in a later authorized secret-setup step, on protected storage outside the checkout:

```sh
age-keygen -o /secure/private/location/age-key.txt
age-keygen -y /secure/private/location/age-key.txt
```

Use real protected paths, mode 0600, and an independently protected recovery copy. Copy `.sops.yaml.example` to ignored `.sops.yaml`, replace its recipient with the real public age recipient, then use `sops secrets/service.enc.yaml` to create encrypted content. Only `*.enc.yaml` secret files may be committed. Encrypted files still disclose metadata and key names; keep names minimal. Avoid plaintext temporary files in the checkout.

Provision the intended host's identity at `/var/lib/sops-nix/key.txt` with root ownership and mode 0600 using a separately planned secure provisioning/recovery procedure. The repository does not generate or provision it. Declare `sops.secrets.NAME` with the encrypted `sopsFile`, then give services the runtime `config.sops.secrets.NAME.path` via an appropriate file-based credential interface, such as systemd LoadCredential. Set least-privilege owner/mode. Never use `builtins.readFile` on decrypted content or interpolate a token into an expression. The Nix store is readable by other users.

Rotate by introducing a new identity/recipient, `sops updatekeys` on each encrypted file, provisioning the new private key and testing decryption, then removing old recipients and rotating upstream credentials. Old Git revisions remain decryptable with old keys. Recover via protected independent key backups and a tested restoration procedure. Without any surviving decrypting identity, encrypted content cannot be recovered: recreate/revoke credentials at each provider.

## Access and agents

SSH is key-only for the configured `homelab.adminUser` (default `admin`, audited account in the private profile); its password is locked and sudo is passwordless, so an admin key grants root-equivalent access. Before installation prove that the key works and establish console recovery. Do not replace a working Debian authentication path during preparation. Firewall allows SSH; no NFS or application ports are opened. Keep the server off public port forwarding. Tailscale remains off until enrollment and ACL policy are reviewed. Verify private SSH before narrowing LAN access; Tailscale availability must not be the only recovery route.

Hermes is blocked pending identification of the exact upstream project/version, supported package and execution entry point, runtime dependencies, command execution model, required egress and full state inventory. Back up memory, sessions, skills, configuration and credentials consistently. No package or migration procedure is invented. No host shell/root mount, private NAS bind or privileged socket is permitted by default.

Qodo PR-Agent is blocked pending verified source/version, Python/runtime packaging, CLI entry point and provider integration. Initial execution is manual/on-demand with an explicit repository allowlist, short-lived credentials, minimal repository permissions, no public webhook, and constrained egress/state. Treat PR contents as untrusted input. Never expose write credentials to untrusted review code; document exact GitHub permissions after validating the chosen integration. OCI instructions alone do not establish native-container compatibility.
