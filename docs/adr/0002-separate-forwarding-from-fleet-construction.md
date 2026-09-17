# Keep node construction outside the library

The library contributes configuration between nodes supplied by the caller. Shared data aggregation, node discovery, topology schemas, and host or guest construction remain outside the library. This boundary keeps dependencies small and allows existing tools to construct the node collection.
