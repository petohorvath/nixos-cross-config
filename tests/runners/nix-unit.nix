# test-standard v1: copied from the test-standard skill; do not edit here.
/*
  Turns a nix-unit entry point into a check entry. The entry point's
  arguments come from the flake inputs, rebuilt from store paths so the
  build sandbox fetches nothing. Each group, an attrset that directly holds
  tests, runs in its own nix-unit process to bound memory.
*/
{
  inputs,
  pkgs,
  repo,
  srcDir,
}:
{
  kind,
  name ? kind,
  suites ? null,
  extraArgs ? { },
  requiredSystemFeatures ? [ ],
  postCheck ? "",
  jobs ? null,
}:
let
  inherit (pkgs) lib;
  inherit (lib) escapeShellArg;
  inherit (lib.strings) escapeNixIdentifier escapeNixString;
  inherit (pkgs.stdenv.hostPlatform) system;

  entryPointPath = "${srcDir}/tests/${kind}";
  evaluationInputsPath = "${srcDir}/tests/helpers/evaluation-inputs.nix";

  # Interpolating each outPath makes the store path an input of the check.
  inputTreeExpression =
    input:
    let
      path = escapeNixString input.outPath;
      dependencyExpressions = lib.mapAttrsToList (
        inputName: dependency: "${escapeNixIdentifier inputName} = ${inputTreeExpression dependency};"
      ) input.inputs;
    in
    if input._type or null == "flake" then
      "{ path = ${path}; inputs = { ${toString dependencyExpressions} }; }"
    else
      "{ path = ${path}; flake = false; }";

  inputArgs = lib.mapAttrs (
    inputName: _: "(import ${evaluationInputsPath}) ${inputTreeExpression inputs.${inputName}}"
  ) (builtins.intersectAttrs inputs (builtins.functionArgs (import entryPointPath)));

  argExpressions = inputArgs // extraArgs;

  argFlags = toString (
    lib.mapAttrsToList (
      argName: expression: "--arg ${escapeShellArg argName} ${escapeShellArg expression}"
    ) argExpressions
    ++ [ "--argstr system ${escapeShellArg system}" ]
  );

  argsExpression = "{ ${
    toString (
      lib.mapAttrsToList (
        argName: expression: "${escapeNixIdentifier argName} = ${expression};"
      ) argExpressions
    )
  } system = ${escapeNixString system}; }";

  /*
    Lists each group as one line of its tests' attribute paths, separated by
    tabs, so a nested group runs once, in its own process. It runs inside
    the sandbox, where every argument is available, including extraArgs
    that refer to derivations.
  */
  groupsProgram = builtins.toFile "nix-unit-groups.nix" ''
    entryPointPath: suites: args:
    let
      isTest = name: builtins.substring 0 4 name == "test";
      showName =
        name:
        if builtins.match "[A-Za-z_][A-Za-z0-9_'-]*" name != null then
          name
        else
          builtins.toJSON name;
      showPath = path: builtins.concatStringsSep "." (map showName path);
      groupsIn =
        path: value:
        let
          names = builtins.attrNames value;
          tests = builtins.filter isTest names;
          testPaths = map (name: showPath (path ++ [ name ])) tests;
        in
        (
          if tests == [ ] then
            [ ]
          else
            [ (builtins.concatStringsSep "\t" testPaths) ]
        )
        ++ builtins.concatMap (
          name:
          let
            child = builtins.getAttr name value;
          in
          if !isTest name && builtins.isAttrs child then
            groupsIn (path ++ [ name ]) child
          else
            [ ]
        ) names;
      testSuites = import entryPointPath args;
      selectedSuites =
        if suites == null then
          testSuites
        else
          builtins.listToAttrs (
            map (name: {
              inherit name;
              value = builtins.getAttr name testSuites;
            }) suites
          );
    in
    builtins.concatStringsSep "\n" (groupsIn [ ] selectedSuites)
  '';

  suitesExpression =
    if suites == null then "null" else "[ ${toString (map escapeNixString suites)} ]";

  groupsExpression = "(import ${groupsProgram}) ${entryPointPath} ${suitesExpression} ${argsExpression}";

  # nix-unit releases before 2.35 need a directory for their GC roots.
  gcRootsFlag = lib.optionalString (lib.versionOlder pkgs.nix-unit.version "2.35") "--gc-roots-dir \"$TMPDIR/gc-roots\"";
in
pkgs.runCommand "${repo}-${name}"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.nix-unit
    ];
    inherit requiredSystemFeatures;
  }
  ''
    export HOME="$TMPDIR"
    # The writable eval store lets NixOS evaluation add derivations inside the
    # sandbox.
    evalStore="$TMPDIR/eval-store"

    nix --extra-experimental-features nix-command eval --raw --impure \
      --store "$evalStore" --expr ${escapeShellArg groupsExpression} >groups
    mapfile -t groups <groups
    if (( ''${#groups[@]} == 0 )); then
      echo "tests/${kind} holds no test groups" >&2
      exit 1
    fi

    runGroup() {
      local log=$1 status=0 testPath
      local -a testPaths attrFlags=()
      IFS=$'\t' read -r -a testPaths <<<"$2"
      for testPath in "''${testPaths[@]}"; do
        attrFlags+=(--attr "$testPath")
      done
      nix-unit --show-trace --eval-store "$evalStore" ${gcRootsFlag} \
        ${entryPointPath} "''${attrFlags[@]}" ${argFlags} \
        >"$log" 2>&1 || status=$?
      cat "$log"
      if (( status != 0 )); then
        echo "nix-unit exited with status $status for:" "''${testPaths[@]}" >&2
      fi
      return "$status"
    }

    maxJobs=${if jobs == null then "$NIX_BUILD_CORES" else toString jobs}
    if (( maxJobs < 1 )); then
      maxJobs=1
    fi
    running=0
    failed=0
    for index in "''${!groups[@]}"; do
      if (( running >= maxJobs )); then
        wait -n || failed=1
        running=$((running - 1))
      fi
      runGroup "$TMPDIR/group-$index.log" "''${groups[index]}" &
      running=$((running + 1))
    done
    while (( running > 0 )); do
      wait -n || failed=1
      running=$((running - 1))
    done
    if (( failed )); then
      echo "Some nix-unit groups failed." >&2
      exit 1
    fi

    ${postCheck}
    touch "$out"
  ''
