# Separate Forwarding From Fleet Construction

The library forwards configuration between nodes supplied by the caller. Globals aggregation, node discovery, topology schemas, and host or guest construction remain outside the library, although extraction candidate 6 groups them together. This boundary keeps dependencies small and allows existing fleet builders to supply the participating nodes.
