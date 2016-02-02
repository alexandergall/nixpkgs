{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.snabbswitch.programs.l2vpn;
  cfg-snabb = config.services.snabbswitch;
  cfg-snmpd = config.services.snmpd;
  cfg-exabgp = config.services.exabgp;
  mkSubmodule = module:
    types.submodule (import module { inherit lib; });
in
{
  options = {
    services.snabbswitch.programs.l2vpn = {
      programOptions = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = literalExample ''-jv=dump'';
        description = ''
          Default command-line options to pass to each service instance.
          If not specified, the global default options are applied.
        '';
      };
      instances = mkOption {
        default = {};
        description = ''
          Set of definitions of L2VPN termination points.
        '';
        example = literalExample ''TBD'';
        type = types.attrsOf (types.submodule {
          options = {

            ### L2VPN instance configuration options

            enable = mkOption {
	      type = types.bool;
              default = false;
              description = ''
                Whether to start this VPLS instance.
              '';
            };

            programOptions = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = literalExample ''-jv=dump'';
              description = ''
                Command-line options to pass to this service instance.
                If not specified, the default options are applied.
              '';
            };
            uplink = {
              interface = mkOption {
                type = mkSubmodule ../../modules/interface.nix;
                default = {};
                description = ''
                  Interface definition.
                '';
              };
              ipv6Address = mkOption {
                type = types.str;
                default = "";
		example = "2001:DB8:0:1::1";
                description = ''
                  The IPv6 address of the interface.
                '';
              };
              macAddress = mkOption {
                type = types.str;
                default = "";
                example = "28:94:0f:fd:49:40";
                description = ''
                  The MAC address of the interface.
                '';
              };
              nextHop = mkOption {
                type = types.str;
                default = "";
		example = "2001:DB8:0:1::1";
                description = ''
                  The IPv6 address of the next hop for all packets
                  that are sent out of the interface.
                '';
              };
              neighborMacAddress = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "28:94:0f:fd:49:40";
                description = ''
                  Optional static configuration of the MAC address associated
                  with next_hop.  If set to null, dynamic neighbor discovery
                  is initiated to resolv the next_hop address.
                '';
              };
              inboundND = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  If the MAC address of the next-hop address is
                  configured statically, this option selects whether
                  neighbor discovery for incoming address resolution
                  requests should be enabled via the ns_responder app.
                  It is ignored if dynamic neighbor discovery is
                  configured.
                '';
              };
            };

            vpls = let
              tunnelOption = { maybeNull ? false, default ? { type = "l2tpv3"; } }: {
                type = (if maybeNull then types.nullOr else id) (mkSubmodule ./tunnel.nix);
                inherit default;
                example = literalExample ''
                  { type = "l2tpv3";
                    localCookie = "\x00\x11\x22\x33\x44\x55\x66\x77";
                    remoteCookie = "\x00\x11\x22\x33\x44\x55\x66\x77";
                  }
                '';
                description = ''
                  The configuration of the tunnel used by a pseudowire.
                '';
              };
              controlChannelOption = { maybeNull ? false, default ? { heartbeat = 10; deadFactor = 3; } }: {
                type = (if maybeNull then types.nullOr else id) (mkSubmodule ./control-channel.nix);
                inherit default;
                example = literalExample ''
                  default = {
                    heartbeat = 10;
                    deadFactor = 3;
                  };
                '';
                description = ''
                  The configuration of the control-channel.
                '';
              };
            in mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  description = mkOption {
                    type = types.str;
                    default = "";
                    description = ''
                      Description of this VPLS instance.
                    '';
                  };
                  mtu = mkOption {
                    type = types.int;
                    default = null;
                    description = ''
                      The MTU of the uplink interface.  This value will be advertised to
                      all remote pseudowire endpoints over the control-channel, if enabled.
                    '';
                  };
                  vcID = mkOption {
                    type = types.int;
                    default = 1;
                    description = ''
                      The VC ID assigned to this VPLS instance.  It is advertised through the
		      control channel (and required to be identical on both sides of a
		      pseudowire) but not used for multiplexing/demultiplexing of VPN
		      traffic.
                    '';
                  };
                  address = mkOption {
                    type = types.str;
                    default = null;
		    example = "2001:DB8:0:1::1";
                    description = ''
                      The IPv6 address which uniquely identifies the VPLS instance.
                    '';
                  };
                  defaultTunnel = mkOption (tunnelOption {});
                  defaultControlChannel = mkOption (controlChannelOption {});
                  bridge = mkOption {
                    type = mkSubmodule ../../modules/bridge.nix;
                    description = ''
                      Bridge configuration.
                    '';
                  };
                  attachmentCircuits = mkOption {
                    type = types.attrsOf (types.submodule {
                      options = {
                        interface = mkOption {
                          type = mkSubmodule ../../modules/interface.nix;
                          default = {};
                          description = ''
                            Interface definition.
                          '';
                        };
                      };
                    });
                    default = {};
                    description = ''
                      A set of customer-facing interfaces which will be connected
                      to the VPLS instance.
                    '';
                  };
                  pseudowires = mkOption {
                    type = types.attrsOf (types.submodule {
                      options = {
                        address = mkOption {
                          type = types.str;
                          default = null;
		          example = "2001:DB8:0:1::1";
                          description = ''
                            The IPv6 address of the remote end of the tunnel.
                          '';
                        };
                        tunnel = mkOption (tunnelOption { maybeNull = true; default = null; });
                        controlChannel = mkOption (controlChannelOption { maybeNull = true; default = null; });
                      };
                    });
                    default = {};
                    description = ''
                      Definition of the pseudowires attached to the VPLS instance.  The
		      pseudowires must be configured as a full mesh between all
		      endpoints which are part of the same VPLS.
                    '';
                  };
                };
              });
              default = {};
              description = ''
                Set of VPLS instances.
              '';
            };
          };
        }); # submodule
      }; # instances
    }; # programs.l2vpn
  }; #options

  config = mkIf cfg-snabb.enable {

    ## Register each VPLS endpoint as a Snabb instance.
    ## The implementation of services.snabbswitch will
    ## generate systemd services from them.
    services.snabbswitch.instances = let
      boolToString = val:
        if val then "true" else "false";

      driverModule = iface:
        ''require("${iface.driver.path}").${iface.driver.name}'';

      driverConfig = iface:
        let pciAddress = iface.config.pciAddress;
        in if any (addr: pciAddress == addr) cfg-snabb.interfaces then
          ''{ pciaddr = "${pciAddress}",
                 mtu = ${toString iface.config.mtu},
                 ${optionalString iface.config.snmpEnable
                                  ''snmp = { directory = "${cfg-snabb.shmemDir}" }''}
            }
          ''
        else
          throw "L2VPN: PCI address ${pciAddress} is not declared in services.snabbswitch.interfaces";

      acConfig = name: ac:
        ''${name} = {
                 driver = ${driverModule ac.interface},
                 config = ${driverConfig ac.interface},
                 interface = "${ac.interface.config.pciAddress}",
                },
        '';

      tunnelConfig = tunnel:
        ''tunnel = {
          ${if tunnel.type == "l2tpv3" then
                 let conf = tunnel.config.l2tpv3;
                 in '' type = "l2tpv3",
                       local_cookie = "${conf.localCookie}",
                       remote_cookie = "${conf.remoteCookie}"
                    ''
             else
               if tunnel.type == "gre" then
                 let conf = tunnel.config.gre;
                 in '' type = "gre",
                       ${optionalString (conf.key != null) ''key = ${conf.key}''}
                       checksum = ${boolToString conf.checksum}
                     ''
               else
                 ""}
            },
          '';

      ccConfig = cc:
        ''cc = {
            heartbeat = ${toString cc.heartbeat},
            dead_factor = ${toString cc.deadFactor}
          },
        '';

      pwConfig = name: pw:
        ''${name} = {
            address = "${pw.address}",
            ${optionalString (pw.tunnel != null) (tunnelConfig pw.tunnel)}
            ${optionalString (pw.controlChannel != null) (ccConfig pw.controlChannel)}
           },
         '';

      mkConfigIterator = attr: f:
        set: concatStrings (map (name: f name (getAttr name set.${attr})) (attrNames set.${attr}));

      vplsConfig = name: vpls:
        ''${name} = {
            description = "${vpls.description}",
            mtu = ${toString vpls.mtu},
            vc_id = ${toString vpls.vcID},
            address = "${vpls.address}",
            bridge = {
              type = "${vpls.bridge.type}",
              ${let bridge = vpls.bridge; in if bridge.type == "learning" then
                  let mac = bridge.config.learning.macTable;
                  in ''config = {
		         mac_table = { verbose = ${boolToString mac.verbose},
                         timeout = ${toString mac.timeout} }
		       }
		     ''
                else
                  ""}
             },
             ${optionalString (length (attrNames vpls.defaultTunnel) != 0)
                              (tunnelConfig vpls.defaultTunnel)}
             ${optionalString (length (attrNames vpls.defaultControlChannel) != 0)
                              (ccConfig vpls.defaultControlChannel)}
             shmem_dir = "${cfg-snabb.shmemDir}",
             ac = {
               ${(mkConfigIterator "attachmentCircuits" acConfig) vpls}
             },
             pw = {
               ${(mkConfigIterator "pseudowires" pwConfig) vpls}
             },
          },
        '';

      instanceConfig = name: config:
        let
          uplink = config.uplink;
        in pkgs.writeText "l2vpn-${name}" ''
          return {
            uplink = {
              driver = ${driverModule uplink.interface},
              config = ${driverConfig uplink.interface},
              address = "${uplink.ipv6Address}",
              mac = "${uplink.macAddress}",
              next_hop = "${uplink.nextHop}",
              ${optionalString (uplink.neighborMacAddress != null)
                  ''neighbor_mac = "${uplink.neighborMacAddress}", '' +
                  ''neighbor_nd = '' + boolToString uplink.inboundND}
             },
             vpls = {
               ${(mkConfigIterator "vpls" vplsConfig) config}
             }
           }
          '';

      mkL2VPNService = name: config: {
        name = "snabb-l2vpn-" + name;
        inherit (config) enable;
        description = "Snabb L2VPN termination point ${name}";
        programName = "l2vpn";
        programOptions = optionalString (config.programOptions != null)
                                        config.programOptions;
        programArgs = "${instanceConfig name config}";
      };
    in map (name: mkL2VPNService name cfg.instances.${name})
       (attrNames cfg.instances);

    ## Register the SNMP sub-agent that handles the L2VPN-related
    ## MIBs with the SNMP daemon.
    services.snmpd.agentX.subagents = mkIf cfg-snmpd.enable [
      rec {
        name = "pseudowire";
        executable = pkgs.snabbSNMPAgents + "/bin/${name}";
        args = "--mibs-dir=${pkgs.snabbPwMIBs} --shmem-dir=${cfg-snabb.shmemDir}";
      }
    ];

    ## Generate the list of IPv6 addresses and associated next-hops
    ## that need to be announced as static routes through BGP.  There
    ## is no point in making these advertisements dynamic, e.g. withdraw
    ## them when the VPN service is down, since there is nowhere else
    ## these packets could go.
    services.exabgp.staticRoutes = mkIf cfg-exabgp.enable (let
      mkRoute = nextHop: vpls:
        { route = "${vpls.address}/128";
          inherit nextHop; };

      mkRoutes = instance:
        map (vpls: mkRoute instance.uplink.ipv6Address vpls) (mapAttrsToList (name: value: value) instance.vpls);

    in flatten (map mkRoutes (mapAttrsToList (name: value: value) cfg.instances)));

  }; # config
}
