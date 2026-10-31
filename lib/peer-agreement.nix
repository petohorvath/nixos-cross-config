# Checks that this node and its peers agree on the shared settings. Receivers
# collect through their own settings, so a disagreement would otherwise drop
# contributions without an error.
{
  contributions,
  lib,
  name,
  nodeConfigurations,
  optionPaths,
}:
let
  # Entries outside the module, such as unrelated flake configurations,
  # receive nothing and are not compared.
  participates = node: node.config ? crossConfig;

  showNames = lib.concatMapStringsSep ", " (entry: "`${entry}`");
  showPaths = lib.concatMapStringsSep ", " (path: "`${lib.showOption path}`");

  membershipAssertion = {
    assertion = builtins.hasAttr name nodeConfigurations;
    message = "nixos-cross-config: node `${name}` is missing from its own crossConfig.nodeConfigurations.";
  };

  mkReceiverAssertions =
    receiver: contribution:
    let
      isKnown = builtins.hasAttr receiver nodeConfigurations;
    in
    [
      {
        assertion = builtins.seq contribution isKnown;
        message = "nixos-cross-config: sender `${name}` targets unknown receiver `${receiver}`.";
      }
      {
        assertion = !isKnown || participates nodeConfigurations.${receiver};
        message = "nixos-cross-config: sender `${name}` targets receiver `${receiver}`, which does not import the module.";
      }
    ];

  mkPeerAssertion =
    key: node:
    let
      peer = node.config.crossConfig;
      ownNames = builtins.attrNames nodeConfigurations;
      peerNames = builtins.attrNames peer.nodeConfigurations;
      # Paths compare as sets: receivers merge in their own path order.
      onlyOwnPaths = lib.subtractLists peer.optionPaths optionPaths;
      onlyPeerPaths = lib.subtractLists optionPaths peer.optionPaths;
      onlyOwnNames = lib.subtractLists peerNames ownNames;
      onlyPeerNames = lib.subtractLists ownNames peerNames;
      differences = lib.concatLists [
        (lib.optional (peer.name != key) "Its crossConfig.name is `${peer.name}`.")
        (lib.optional (onlyOwnPaths != [ ]) "Only `${name}` allows ${showPaths onlyOwnPaths}.")
        (lib.optional (onlyPeerPaths != [ ]) "Only `${key}` allows ${showPaths onlyPeerPaths}.")
        (lib.optional (
          onlyOwnNames != [ ]
        ) "Only the collection of `${name}` contains ${showNames onlyOwnNames}.")
        (lib.optional (
          onlyPeerNames != [ ]
        ) "Only the collection of `${key}` contains ${showNames onlyPeerNames}.")
      ];
    in
    {
      assertion = differences == [ ];
      message =
        "nixos-cross-config: node `${name}` and collection entry `${key}` disagree on shared settings.\n"
        + lib.concatStringsSep "\n" differences;
    };

  # Nodes with paths already read every peer; idle nodes read only the
  # receivers they target, so their collections stay unforced.
  checkedPeers = lib.pipe nodeConfigurations [
    (entries: if optionPaths != [ ] then entries else builtins.intersectAttrs contributions entries)
    (lib.filterAttrs (_: participates))
  ];
in
[ membershipAssertion ]
++ lib.concatLists (lib.mapAttrsToList mkReceiverAssertions contributions)
++ lib.mapAttrsToList mkPeerAssertion checkedPeers
