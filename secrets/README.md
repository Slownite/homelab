# Encrypted secrets only

No secrets are configured. See [security](../docs/security.md) for age recipients, runtime decryption, rotation and recovery. Commit only reviewed SOPS-encrypted `*.enc.yaml`; never private keys or plaintext application state. The ignored `.sops.yaml` must be populated with real public recipients before encrypting. Back up decrypting identities independently.
