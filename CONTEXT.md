# Distributed Configuration

Vocabulary for configuration contributed between nodes.

## Language

**Node**:
A host or guest that participates in configuration contributions.

**Node collection**:
The set of named nodes participating in configuration contributions.

**Node identity**:
A node's name within its node collection, independent of its hostname.

**Forwarding surface**:
The shared set of options eligible for contributions within a node collection.

**Sender**:
The node that declares a configuration contribution.

**Receiver**:
The node whose configuration includes a contribution. A receiver can also be the sender of that contribution.

**Configuration contribution**:
Configuration declared by a sender for the receiver's eligible writable options.
