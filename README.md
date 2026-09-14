# nixos-cross-config

A planned NixOS library for configuration contributions between caller-supplied nodes, using the consumer's existing Nixpkgs library.

- [Domain glossary](./CONTEXT.md)
- [Architectural decisions](./docs/adr/)

The implementation covers the standalone library and migration of the existing `nixos-config` consumer. Work is tracked in GitHub Issues.

## Implementation plan

1. [Forward contributions through a caller-owned node collection](https://github.com/petohorvath/nixos-cross-config/issues/1)
2. [Preserve override priorities and ordering in contributions](https://github.com/petohorvath/nixos-cross-config/issues/2)
3. [Preserve conditional contributions and sender context](https://github.com/petohorvath/nixos-cross-config/issues/3)
4. [Support self-targeted and reciprocal node contributions](https://github.com/petohorvath/nixos-cross-config/issues/4)
5. [Validate destinations and report contribution origins](https://github.com/petohorvath/nixos-cross-config/issues/5)
6. [Adopt the library in the consumer and migrate Vaultwarden](https://github.com/petohorvath/nixos-cross-config/issues/6)
7. [Migrate the remaining nginx publication integrations](https://github.com/petohorvath/nixos-cross-config/issues/7)
8. [Migrate metrics and log access contributions](https://github.com/petohorvath/nixos-cross-config/issues/8)
9. [Remove legacy forwarding after the consumer cutover](https://github.com/petohorvath/nixos-cross-config/issues/9)
