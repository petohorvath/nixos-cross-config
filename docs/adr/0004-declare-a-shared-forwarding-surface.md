# Declare the allowed option paths

The node collection uses one explicit shared set of allowed option paths, configured through `crossConfig.optionPaths`. Shared modules can merge and prioritize registrations, with duplicate paths normalized after merging. Every participant must use the same node collection and normalized path set.

The receiving configuration's outer namespace names come from the receiver's declared options. Allowed-path filtering and contribution collection happen only inside each namespace. This keeps the outer structure independent of the path list and receiving values, allowing settings to participate in ordinary module evaluation without another registration-discovery stage.

Path registrations must remain independent of receiving configuration. Literal paths, list merging, override priorities, and conditions based on independent setup values are supported. Even a locally defined flag in a generated receiving namespace can create a cycle when it selects registrations. Prefer unconditional registrations with conditions on contributions. Caller-owned construction, receiver-owned declarations, and the single-computation boundary remain unchanged.

The roots `crossConfig` and `_module` are reserved and excluded from receiving definitions so contributions cannot alter setup or module-system internals. Nested attributes and tags with these names remain eligible under ordinary receiving options.

Listing a path does not require every node to declare the option. A contribution to an absent option fails.

[Issue #24](https://github.com/petohorvath/nixos-cross-config/issues/24) revises the earlier requirement to supply paths before node evaluation. The stable receiving structure makes module-option composition possible while retaining explicit shared registrations and the dependency constraint; discovering registrations from evaluated nodes remains outside the contract.
