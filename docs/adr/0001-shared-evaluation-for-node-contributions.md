# Compose Node Contributions Within One Nix Computation

Participating node configurations must be accessible within one Nix computation, allowing contributions to become part of the receiver's generated configuration. This keeps the library small by avoiding a separate exchange protocol or runtime coordination; deploying the receiver activates the result. Source modules may come from separate repositories, and each node may have its own module-system evaluation.

Self-targeted and reciprocal contributions are allowed. Cycles between sender and receiver identities are not inherently value-dependency cycles; actual value-dependency cycles retain Nix's normal recursion errors.
