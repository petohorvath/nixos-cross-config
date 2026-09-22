{ lib, tests }:
let
  collect =
    path: value:
    if path != [ ] && lib.hasPrefix "test" (lib.last path) then
      let
        name = lib.showAttrPath path;
        trace = value.expectedError.trace or [ ];
      in
      assert lib.assertMsg (
        builtins.isList trace && builtins.all builtins.isString trace
      ) "${name}: expectedError.trace must be a list of strings";
      [
        {
          inherit name trace;
          # Share successful fixture evaluations; isolate errors to bound memory.
          batch = lib.showAttrPath (if value ? expectedError then path else lib.init path);
        }
      ]
    else
      lib.concatMap (name: collect (path ++ [ name ]) value.${name}) (builtins.attrNames value);
in
collect [ ] tests
