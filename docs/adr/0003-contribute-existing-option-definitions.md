# Contribute Definitions To Existing Options

Contributions define existing options on the receiving node. Module imports and option declarations remain part of the receiver's own module structure: deriving that structure from another node's evaluated configuration can create a cycle before configuration merging begins. This preserves the small forwarding scope without introducing a separate declaration phase or restrictions that require the node graph to be acyclic.
