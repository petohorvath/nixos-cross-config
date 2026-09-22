{ lib }:
fragments:
# Independent lookaheads match literal fragments in any order, across newlines.
lib.concatMapStrings (fragment: "(?=[\\s\\S]*${lib.escapeRegex fragment})") fragments
