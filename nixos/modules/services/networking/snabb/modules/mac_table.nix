{ lib }:

with lib;

{
  options = {
    timeout = mkOption {
      type = types.int;
      default = 30;
      description = ''
        The interval in seconds, after which a dynamically learned source MAC
        address is deleted from the MAC address table if no activity has been
        observed during that interval.
      '';
    };
    verbose = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, report information about table usage
        at every timeout interval.
      '';
    };
  };
}
