{ lib }:

with lib;

{
  options = {
    heartbeat = mkOption {
      type = types.int;
      default = 10;
      example = literalExample ''10'';
      description = ''
        The interval in seconds at which heartbeat messages
        are sent to the peer.
      '';
    };
    deadFactor = mkOption {
      type = types.int;
      default = 3;
      example = literalExample ''3'';
      description = ''
        The number of successive heartbeat intervals after which the peer is
        declared to be dead (unrechable) unless at least one heartbeat message
        has been received.
      '';
    };
  };
}
