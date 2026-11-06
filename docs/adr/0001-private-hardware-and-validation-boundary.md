# Separate public validation from private hardware configuration

The public repository must be useful before the Latitude has been inspected without suggesting that validation establishes installation readiness. The user agreed that `nixosConfigurations.latitude` must fail closed until a separate, ignored private hardware configuration supplies verified disk, boot, networking, and administrator access settings; CI will use an explicitly non-deployable validation configuration.

Machine-specific disk identifiers, network details, and administrator public keys remain in that private configuration, with a documented example tracked publicly. This protects unnecessary infrastructure details from irreversible public disclosure, at the cost of requiring a separately preserved configuration alongside the pinned public repository to reproduce a deployment. Runtime secrets remain a separate concern.
