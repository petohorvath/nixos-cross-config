# Declare the allowed option paths

The node collection uses one explicit shared list of allowed option paths. The list must be available before node configuration is evaluated. Discovering it from other nodes' configuration values could create a dependency cycle. Callers choose the list, so the library does not need to know which services the nodes use.

Listing a path does not require every node to declare the option. A contribution to an absent option fails.
