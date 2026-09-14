# Declare A Shared Forwarding Surface

The node collection uses one explicit shared list of eligible option paths. This keeps the forwarding structure available before node configuration is evaluated, avoiding the structural dependency created by discovering that structure from other nodes' configuration values. Callers choose the list, so service-specific paths remain outside the library.

Registration alone does not require every participant to declare every eligible option; a contribution targeting an absent option fails.
