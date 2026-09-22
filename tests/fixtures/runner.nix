{ nixpkgs, ... }:
{
  passing = {
    testValue = {
      expr = nixpkgs.lib.concatStrings [
        "receiver"
        "-value"
      ];
      expected = "receiver-value";
    };
    testError = {
      expr = throw "The intended rejection.";
      expectedError = {
        type = "ThrownError";
        msg = "intended rejection";
        trace = [ "The intended rejection." ];
      };
    };
  };
  mismatches = {
    testValue = {
      expr = 1;
      expected = 2;
    };
    testErrorType = {
      expr = throw "The intended rejection.";
      expectedError.type = "TypeError";
    };
    testErrorMessage = {
      expr = throw "An unrelated rejection.";
      expectedError = {
        type = "ThrownError";
        msg = "intended rejection";
      };
    };
    testMissingError = {
      expr = true;
      expectedError.type = "ThrownError";
    };
    testDiagnostic = {
      expr = throw "The intended rejection.";
      expectedError = {
        type = "ThrownError";
        msg = "intended rejection";
        trace = [ "Missing source context." ];
      };
    };
  };
  discovery.testLazy = {
    expr = abort "Test discovery must leave expressions lazy.";
    expected = true;
  };
}
