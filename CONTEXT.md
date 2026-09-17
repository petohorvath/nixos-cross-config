# Distributed Configuration

Vocabulary for configuration contributed between nodes.

## Language

**Node**:
A named NixOS configuration for a host or guest that participates in configuration contributions.

**Node collection**:
The set of named nodes participating in configuration contributions.

**Node identity**:
A node's name within its node collection, independent of its hostname.

**Allowed option paths**:
The shared set of option paths that a node collection permits for contributions. A receiver must declare a writable option at a path to receive a contribution there.
_Avoid_: Forwarding surface

**Sender**:
The node that declares a configuration contribution.

**Receiver**:
The node whose configuration includes a contribution. A receiver can also be the sender of that contribution.

**Configuration contribution**:
Option definitions that a sender supplies for a receiver.
