config:

with builtins;

rec {
  getAddress = transport: type:
    let
      cfg = config.services.snabb.programs.l2vpn;
      peersOfType = cfg.peers.${type};
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
      address = if hasAttr peer peersOfType then
                  if hasAttr ep peersOfType.${peer}.endpoints then
                    let
                       thisEp = peersOfType.${peer}.endpoints.${ep};
                    in if thisEp.addressFamily == afi then
                      ## The remote address is only used as traffic
                      ## selector for IKE.  If the the remote end is
                      ## behind a NAT, the selector must be the inside
                      ## (private) address rather than the outside (public)
                      ## one.  The inside address is stored in a separate
                      ## option.
                      if (type == "remote" && thisEp.addressNATInside != null) then
                        thisEp.addressNATInside
                      else
                        thisEp.address
                    else
                      err ("address family mismatch for ${peer}/${ep}: " +
                            "expected ${afi}, got ${thisEp.addressFamily}")
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
