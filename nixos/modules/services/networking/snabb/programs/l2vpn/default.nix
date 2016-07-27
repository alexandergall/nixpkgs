{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.snabb.programs.l2vpn;
  cfg-snabb = config.services.snabb;
  cfg-snmpd = config.services.snmpd;
  cfg-exabgp = config.services.exabgp;
  mkSubmodule = module:
    types.submodule (import module { inherit lib; });

  ## Parse an interface specifiers of
  ## the form <intf>.<subintf>, where <intf> must refer to an
  ## existing attribute of cfg-snabb.interfaces.
  checkIfSpec = ifSpec:
    let
      intfs = cfg.interfaces;
      parts = splitString "." ifSpec;
     in
       if ((count (x: true) parts) == 2) then
         let
           i = {
             intf = elemAt parts 0;
             subintf = elemAt parts 1;
             inherit ifSpec;
           };
         in
           if hasAttr i.intf intfs then
             i // { conf = intfs."${i.intf}"; }
           else
             throw "interface reference ${ifSpec}: interface ${i.intf} does not exist"
       else
         throw "illegal interface specifier ${ifSpec}";

  ## Assert that no L3 configuration for the subinterface exists.
  l2IfRef = ifSpec:
    let
      i = checkIfSpec ifSpec;
     in
       if hasAttr "l3" i.conf && hasAttr i.subintf i.conf.l3 then
         throw "interface ${ifSpec} is a L3 subinterface when a L2 subinterface was expected"
     else
       i;

  ## Augment the set from checkIfSpec with the configuration of
  ## the L3 subinterface
  l3IfRef = ifSpec:
    let
      i = checkIfSpec ifSpec;
     in
       if hasAttr "l3" i.conf && hasAttr i.subintf i.conf.l3 then
         i // { subConf = i.conf.l3."${i.subintf}"; }
     else
       throw "interface ${i.intf} does not have a l3 subinterface named ${i.subintf}";

in
{
  options = {
    services.snabb.programs.l2vpn = {
      programOptions = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = literalExample ''-jv=dump'';
        description = ''
          Default command-line options to pass to each service instance.
          If not specified, the global default options are applied.
        '';
      };
      interfaces = mkOption {
        default = {};
        description = ''
          A set of interface definitions.
        '';
        type = types.attrsOf (types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              default = null;
              example = literalExample ''name = "0000:03:00.1"'';
              description = ''
                The system-wide unique name of the interface.  On conventional
                network devices, this is typicially something like
                <literal>&lt;type&gt;&lt;slot&gt;/&lt;number&gt;</literal>,
                e.g. TenGigabitEthernet3/2.  By convention, the Snabb system
                currently uses the full PCI address of the NIC.  However, the
                name is not derived from the actual PCI address as used in the
                configuration of the driver to accomodate futurue conventions,
                which might not be tied to the PCI address.  An error is thrown
                if the name does not occur in the list of option
                <option>services.snabb.interfaces</option>.  That list is used
                to generate a persistent mapping of interface names to interface
                indices used, for example, for SNMP.  This implies that the name
                is stored in the ifDesc SNMP object.
              '';
            };
            ifIndex = mkOption {
              type = types.int;
              description = ''
                The index which uniquely identifies the interface.  This value
                is used as index into the SNMP ifTable and ifXTable tables.
              '';
            };
            description = mkOption {
              type = types.nullOr types.str;
              example = literalExample ''10GE-SFP+ link to foo'';
              description = ''
                An optional verbose description of the interface.  This string
                is exposed in the ifAlias object if SNMP is enabled for the
                interface.
              '';
            };
            driver = {
              path = mkOption {
                type = types.str;
                example = literalExample ''apps.intel.intel_app'';
                description = ''
                  The path of the Lua module in which the driver resides.
                '';
              };
              name = mkOption {
                type = types.str;
                example = "Intel82599";
                description = ''
                  The name of the driver within the module referenced by path.
                '';
              };
              config = {
                snmpEnable = mkOption {
                  type = types.bool;
                  default = false;
                  description = ''
                    Whether to enable SNMP support in the driver.
                  '';
                };
              };
            };
            l2 = {
              mtu = mkOption {
                type = types.int;
                default = 1514;
                example = 9014;
                description = ''
                  The MTU of the interface in bytes, including the full Ethernet
                  header.  In particular, if the interface is configured as
                  VLAN trunk, the 4 bytes attributed to the VLAN tag must be
                  included in the MTU.
                '';
              };
              trunk = {
                enable = mkOption {
                  type = types.bool;
                  default = false;
                  description = ''
                    Whether to configure the interface as a VLAN trunk.
                  '';
                };
                encapsulation = mkOption {
                  type = types.either (types.enum [ "dot1q" "dot1ad" ])
                                      types.str;
                  default = "dot1q";
                  example = literalExample ''encapsulation = "0x9100";'';
                  description = ''
                    The encapsulation used on the VLAN trunk (ignored if
                    trunking is disabled), either "dot1q" or "dot1ad" or an
                    explicit ethertype.  The ethertypes for "dot1a" and "dot1ad"
                    are set to 0x8100 and 0x88a8, respectivley.  An explicit
                    ethertype must be specified as a string to allow
                    hexadecimal values.  The value itself will be evaluated
                    when the configuration is processed by Lua.
                  '';
                };
              };
              macAddress = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = literalExample ''macAddress = "00:00:00:01:02:03"'';
                description = ''
                  The physical MAC address of the interface.  This is
                  currently required if L3 subinterfaces are present
                  (it should be automatically read from the NIC).
                '';
              };
            };
            l3 = mkOption {
              default = {};
              description = ''
                A set of subinterface defintions.  The name of a
                subinterface must either be "native" or be of the form
                <literal>"vlan&gt;VID&lt;"</literal>, where VID is a
                number in the range 1-4094.
              '';
              type = types.attrsOf (types.submodule {
                options = {
                  description = mkOption {
                    type = types.str;
                    default = "";
                    description = ''
                      A verbose description of the interface.
                    '';
                  };
                  address = mkOption {
                    type = types.str;
                    description = ''
                      The IPv6 address assigned to the interface.  A netmask
                      of /64 is implied.
                    '';
                  };
                  nextHop = mkOption {
                    type = types.str;
                    description = ''
                      The IPv6 address used as next-hop for all packets
                      sent outbound on the interface.  It must be part of
                      the same subnet as the local address.
                    '';
                  };
                  nextHopMacAddress = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = ''
                      The optional MAC address that belongs to the
                      <option>nextHop</option> address.  Setting this option
                      disables dynamic neighbor discovery for the nextHop
                      address on the interface.
                    '';
                  };
                  enableInboundND = mkOption {
                    type = types.bool;
                    default = true;
                    description = ''
                      If the <option>nextHopMacAddress</option> option is set,
                      this option determines whether neighbor solicitations
                      for the local interface address are processed.  If
                      disabled, the adjacent host must use a static neighbor
                      cache entry for the local IPv6 address in order to be
                      able to deliver packets destined for the interface.  If
                      <option>nextHopMacAddress</option> is not set, this
                      option is ignored.
                    '';
                  };
                };
              });
            };
          }; # options
        }); # submodule
      }; # interfaces

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

            vpls = let
              tunnelOption = { maybeNull ? false,
                               default ? { type = "l2tpv3"; } }: {
                type = (if maybeNull then types.nullOr else id)
                       (mkSubmodule ./tunnel.nix);
                inherit default;
                example = literalExample ''
                  { type = "l2tpv3";
                    config.l2tpv3 = {
                      localCookie = "\x00\x11\x22\x33\x44\x55\x66\x77";
                      remoteCookie = "\x00\x11\x22\x33\x44\x55\x66\x77";
                    };
                  }
                '';
                description = ''
                  The configuration of the tunnel used by a pseudowire.
                '';
              };
              controlChannelOption = { maybeNull ? false,
                                       default ? { heartbeat = 10;
                                                   deadFactor = 3; } }: {
                type = (if maybeNull then types.nullOr else id)
                       (mkSubmodule ./control-channel.nix);
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
                  uplink = mkOption {
                    type = types.str;
                    description = ''
                      A reference to a L3 interface which is used to send
                      and receive encapsulated packets in the form
                      &lt;interface&gt;.&lt;subinterface&gt;, where
                      interface must refer to one of the attributes in the
                      <option>interfaces</option> option and subinterface
                      must refer to an existing entry in the interface's l3
                      attribute set.
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
                    type = types.attrsOf types.str;
                    default = {};
                    description = ''
                      An attribute set that defines all attachment circuits
                      which will be part of the VPLS instance.  Each AC
                      is defined as a string of the form
                      &lt;interface&gt;.&lt;subinterface&gt;, where
                      interface must refer to one of the attributes in the
                      <option>interfaces</option> option and subinterface
                      must refer to one of its L2 subinterfaces.
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

    ## Use the l2vpn branch of Snabb to provide the package for the
    ## service
    services.snabb.pkg = pkgs.snabbL2VPN;

    ## Register each VPLS endpoint as a Snabb instance.
    ## The implementation of services.snabb will
    ## generate systemd services from them.
    services.snabb.instances = let
      boolToString = val:
        if val then "true" else "false";

      indentBlock = count:
        let
          spaces = concatStrings (genList (i: " ") count);
        in text:
          let
            lines = splitString "\n" text;
          in concatStringsSep "\n" (map (line: concatStrings [ spaces line ]) lines);

      acConfig = name: ac:
        ''

          ${name} = "${(l2IfRef ac).ifSpec}",'';

      tunnelConfig = tunnel:
        ''

          tunnel = {
            ${(indentBlock 2)
              (if tunnel.type == "l2tpv3" then
                 let conf = tunnel.config.l2tpv3; in
                 ''

                   type = "l2tpv3",
                   local_cookie = "${conf.localCookie}",
                   remote_cookie = "${conf.remoteCookie}"''
               else
                 if tunnel.type == "gre" then
                   let conf = tunnel.config.gre; in
                   ''

                     type = "gre",
                     ${optionalString (conf.key != null) ''key = ${conf.key},''}
                     checksum = ${boolToString conf.checksum},''
                 else
                   "")}
          },'';

      ccConfig = cc:
        ''

          cc = {
            heartbeat = ${toString cc.heartbeat},
            dead_factor = ${toString cc.deadFactor}
          },'';

      pwConfig = name: pw:
        ''

          ${name} = {
            address = "${pw.address}",
            ${optionalString (pw.tunnel != null)
                             ((indentBlock 2)
                              (tunnelConfig pw.tunnel))}
            ${optionalString (pw.controlChannel != null &&
                              pw.controlChannel.enable)
                              ((indentBlock 2)
                               (ccConfig pw.controlChannel))}
          },'';

      mkConfigIterator = attr: f:
        set: concatStrings (map (name: f name (getAttr name set.${attr}))
                                (attrNames set.${attr}));

      vplsConfig = name: vpls:
        ''

          ${name} = {
            description = "${vpls.description}",
            uplink = "${(l3IfRef vpls.uplink).ifSpec}",
            mtu = ${toString vpls.mtu},
            vc_id = ${toString vpls.vcID},
            address = "${vpls.address}",
            bridge = {
              type = "${vpls.bridge.type}",
              ${let bridge = vpls.bridge; in
                if bridge.type == "learning" then
                  let mac = bridge.config.learning.macTable; in
                  (indentBlock 4)
                  ''

                    config = {
                      ac_table = { verbose = ${boolToString mac.verbose},
                                   timeout = ${toString mac.timeout} },
                    },''
                else
                  ""}
            },
            ${optionalString (length (attrNames vpls.defaultTunnel) != 0)
                              ((indentBlock 2)
                               (tunnelConfig vpls.defaultTunnel))}
            ${optionalString vpls.defaultControlChannel.enable
                               ((indentBlock 2)
                                (ccConfig vpls.defaultControlChannel))}
            shmem_dir = "${cfg-snabb.shmemDir}",
            ac = { ${(indentBlock 4)
                     ((mkConfigIterator "attachmentCircuits" acConfig) vpls)}
            },
            pw = { ${(indentBlock 4)
                     ((mkConfigIterator "pseudowires" pwConfig) vpls)}
            },
          },'';

      l3Config = subint: conf:
        ''

          ${subint} = {
            description = "${conf.description}",
            address = "${conf.address}",
            next_hop = "${conf.nextHop}",
            ${optionalString (conf.nextHopMacAddress != null)
                ''neighbor_mac = "${conf.nextHopMacAddress}",''}
            neighbor_nd = ${boolToString conf.enableInboundND},
          },'';

      interfaceConfig = name: intf:
        let
          driver = intf.driver;
          intfSnabb = findSingle (s: s.name == intf.name) null null
                                 cfg-snabb.interfaces;
          l2 = intf.l2;
          l3 = intf.l3;
        in if intfSnabb != null then
             ''

               ${name} = {
                 name = "${intf.name}",
                 ${optionalString (intf.description != null)
                     ''description = "${intf.description}",''}
                 driver = {
                   module = require("${driver.path}").${driver.name},
                   config = { pciaddr = "${intfSnabb.pciAddress}",
                              ${optionalString driver.config.snmpEnable
                                ''snmp = { directory = "${cfg-snabb.shmemDir}" }''}
                   },
                 },
                 l2 = {
                   mtu = ${toString l2.mtu},
                   trunk = { enable = ${boolToString l2.trunk.enable},
                             encapsulation = ${
                               let enc = l2.trunk.encapsulation; in
                               if (enc == "dot1q" || enc == "dot1ad") then
                                 ''"${enc}"''
                               else
                                 enc}
                   },
                   ${optionalString (l2.macAddress != null)
                     ''mac = "${l2.macAddress}",''}
                 },
                 ${if (attrNames l3) != [] then
                     ''
                       l3 = { ${(indentBlock 4)
                                  ((mkConfigIterator "l3" l3Config) intf)}
                         },''
                   else
                     ""}
               },''
             else
               throw "L2VPN: the interface named ${intf.name} is not declared in services.snabb.interfaces";

      instanceConfig = name: config:
        let
          uplink = config.uplink;
        in pkgs.writeText "l2vpn-${name}"
          ''
            return {
              interfaces = { ${(indentBlock 4)
                              ((mkConfigIterator "interfaces" interfaceConfig)
                                                  cfg)}
              },
              vpls = { ${(indentBlock 4)
                         ((mkConfigIterator "vpls" vplsConfig) config)}
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
      mkRoute = vpls:
        { route = "${vpls.address}/128";
          nextHop = (l3IfRef vpls.uplink).subConf.address; };

      mkRoutes = instance:
        map (vpls: mkRoute vpls) (mapAttrsToList (name: value: value) instance.vpls);

    in flatten (map mkRoutes (mapAttrsToList (name: value: value) cfg.instances)));

  }; # config
}
