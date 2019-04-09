config:

with builtins;

rec {
  getAddress = transport: type:
    let
      cfg = config.services.snabb.programs.l2vpn;
      tp = if hasAttr transport cfg.transports then
             cfg.transports.${transport}
           else
             throw "undefined transport: ${transport}";
      peer = tp.${type}.peer;
      ep = tp.${type}.endpoint;
      err = msg:
        throw ("transport ${transport}: " + msg);
    in rec {
      afi = tp.addressFamily;
      address = if hasAttr peer cfg.peers.${type} then
                  if hasAttr ep cfg.peers.${type}.${peer}.endpoints then
                    if cfg.peers.${type}.${peer}.endpoints.${ep}.addressFamily == afi then
                      cfg.peers.${type}.${peer}.endpoints.${ep}.address
                    else
                      err ("address family mismatch for ${peer}/${ep}: " +
                            "expected ${afi}, got ${cfg.peers.${type}.${peer}.endpoints.${ep}.addressFamily}")
                  else
                    err "endpoint ${ep} not defined for peer ${peer}"
                else
                  err "undefined peer ${peer}";
    };
  getLocalAddress = transport:
    getAddress transport "local";
  getRemoteAddress = transport:
    getAddress transport "remote";
}
