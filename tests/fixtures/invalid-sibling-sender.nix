# Contributes one writable value and several invalid siblings whose payloads
# fail if evaluated.
{
  crossConfig.contributions.receiver.inventory = {
    entries.alpha = {
      value = "contributed-entry";
      serial.payload = throw "Read-only sibling payload was evaluated.";
      absent.payload = throw "Missing sibling payload was evaluated.";
    };
    tagged.item = {
      value = "contributed-tag";
      absent.payload = throw "Missing tagged sibling payload was evaluated.";
    };
  };
}
