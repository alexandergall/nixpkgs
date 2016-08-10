{ lib }:

with lib;

{
  options = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Wether to enable the control channel.
      '';
    };
    heartbeat = mkOption {
      type = types.int;
      default = 10;
      description = ''
        The interval in seconds at which heartbeat messages
        are sent to the peer.  The value 0 disables the control
        channel.
      '';
    };
    deadFactor = mkOption {
      type = types.int;
      default = 3;
      description = ''
        The number of successive heartbeat intervals after which the peer is
        declared to be dead (unrechable) unless at least one heartbeat message
        has been received.
      '';
    };
  };
}
