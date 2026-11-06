# Repository rules

The execution environment is the Ubuntu workstation. Latitude is a remote production target.

- Keep infrastructure declarative; prefer small native NixOS modules and minimal dependencies.
- Never invent hardware identifiers. External USB storage must remain untouched.
- Installation, disk operations, remote connections and deployments require explicit task authorization. Never run local `nixos-rebuild switch` on Ubuntu.
- Keep secrets out of expressions and the Nix store. Preserve the public repository boundary: private hardware settings belong in ignored `local/`, credentials in encrypted files/runtime paths.
- Use native NixOS containers. Introducing Docker or Kubernetes requires a concrete justification.
- Make incremental, reviewable changes on feature branches; update related documentation.
- Format with `nix fmt`; run `nix flake check --no-update-lock-file`. Report actual results, assumptions, and unresolved hardware requirements.
- Validation is deliberately separate from deployment readiness. Preserve the fail-closed host and non-deployable fixture.
- Before provisioning read docs/installation.md; before deployment read docs/deployment.md; before storage changes read docs/storage.md; before credentials or agent integration read docs/security.md.
- CI validates only. Publishing, provisioning and deployment are manual, explicitly authorized activities.
