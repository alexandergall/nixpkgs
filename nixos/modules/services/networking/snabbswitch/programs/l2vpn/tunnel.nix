{ lib }:

with lib;

{
  options = let
    l2tpv3 = "l2tpv3";
    gre = "gre";
  in {
    type = mkOption {
      type = types.enum [ l2tpv3 gre ];
      default = l2tpv3;
      description = ''
        Tunnel type
      '';
    };
    config.${l2tpv3} = {
      localCookie = mkOption {
        type = types.str;
        default = "\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00";
        example = literalExample ''"\\x00\\x11\\x22\\x33\\x44\\x55\\x66\\x77"'';
        description = ''
          A 64-bit number which is compared to the cookie field of the
          L2TPv3 header of incoming packets.  It must match the value
          configured as remote cookie at the remote end of the tunnel.
          The number must be represented as a string using the convention
          for encoding arbitrary byte values in Lua.
        '';
      };
      remoteCookie = mkOption {
        type = types.str;
        default = "\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00";
        example = literalExample ''"\\x00\\x11\\x22\\x33\\x44\\x55\\x66\\x77"'';
        description = ''
          A 64-bit number which is placed in the cookie field of the
          L2TPv3 header of packets sent to the remote end of the tunnel.
          It must match the value configured as the local cookie at the
          remote end of the tunnel.
          The number must be represented as a string using the convention
          for encoding arbitrary byte values in Lua.
        '';
      };
    };
    config.${gre} = {
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = literalExample ''0x12345678'';
        description = ''
          An optional 32-bit value which is included in the "key" field
          of the GRE header.  If set to null, the key field is not
          included in the header.  If used, both sides of the tunnel must
          use the same value.
        '';
      };
      checksum = mkOption {
        type = types.bool;
        default = false;
        example = literalExample ''true'';
        description = ''
          If true, checksumming is enabled for the GRE tunnel.
        '';
      };
    };
  };
}
