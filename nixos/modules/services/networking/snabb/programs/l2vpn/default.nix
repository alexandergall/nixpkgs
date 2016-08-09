{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.snabb.programs.l2vpn;
  cfg-snabb = config.services.snabb;
  cfg-snmpd = config.services.snmpd;
  cfg-exabgp = config.services.exabgp;
  mkSubmodule = module:
    types.submodule (import module { inherit lib; });

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
        default = [];
        description = ''
          A list of interface definitions.
        '';
        type = types.listOf (mkSubmodule ./interface.nix);
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
              default = {};
              description = ''
                A set of VPLS instance definitions.
              '';
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
                      The MTU of the uplink interface.  This value will be
                      advertised to all remote pseudowire endpoints over
                      the control-channel, if enabled.
                    '';
                  };
                  vcID = mkOption {
                    type = types.int;
                    default = 1;
                    description = ''
                      The VC ID assigned to this VPLS instance.  It is
                      advertised through the control channel (and required to
                      be identical on both sides of a pseudowire) but not used
                      for multiplexing/demultiplexing of VPN traffic.
                    '';
                  };
                  address = mkOption {
                    type = types.str;
                    default = null;
                    example = "2001:DB8:0:1::1";
                    description = ''
                      The IPv6 address which uniquely identifies the VPLS
                      instance.
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
                        tunnel = mkOption (tunnelOption { maybeNull = true;
                                                          default = null; });
                        controlChannel = mkOption (controlChannelOption
                                                     { maybeNull = true;
                                                       default = null; });
                      };
                    });
                    default = {};
                    description = ''
                      Definition of the pseudowires attached to the VPLS
                      instance.  The pseudowires must be configured as a full
                      mesh between all endpoints which are part of the same
                      VPLS.
                    '';
                  };
                }; # options
              }); # submodule
            }; # vpls
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
          in concatStringsSep "\n" (map (line: concatStrings [ spaces line ])
                                        lines);

      acConfig = name: ac:
        ''
          ${name} = "${ac}",
        '';

      tunnelConfig = tunnel:
        ''
          tunnel = {
        '' +
        (indentBlock 2
        (if tunnel.type == "l2tpv3" then
           let conf = tunnel.config.l2tpv3; in
           ''
             type = "l2tpv3",
             local_cookie = "${conf.localCookie}",
             remote_cookie = "${conf.remoteCookie}"
           ''
         else # type "gre"
           let conf = tunnel.config.gre; in
           ''
             type = "gre",
           '' +
           optionalString (conf.key != null)
             (''key = ${conf.key},'' + "\n") +
           ''
             checksum = ${boolToString conf.checksum},
           '')) +
        ''
          }, -- tunnel
        '';

      ccConfig = cc:
        ''
          cc = {
            heartbeat = ${toString cc.heartbeat},
            dead_factor = ${toString cc.deadFactor}
          }, -- cc
        '';

      pwConfig = name: pw:
        ''
          ${name} = {
            address = "${pw.address}",
        '' +
        optionalString (pw.tunnel != null)
                       (indentBlock 2
                        (tunnelConfig pw.tunnel)) +
        (let cc = pw.controlChannel; in
         optionalString (cc != null)
           (indentBlock 2 (ccConfig (pw.controlChannel //
                          (if cc.enable then
                             {}
                           else
                             { heartbeat = 0; }))))) +
        ''
          },
        '';

      mkConfigIterator = attr: f:
        set:
          if isAttrs set.${attr} then
            concatStrings (map (name: f name (getAttr name set.${attr}))
                               (attrNames set.${attr}))
          else
            concatStrings (map f set.${attr});

      vplsConfig = name: vpls:
        ''
          ${name} = {
            description = "${vpls.description}",
            uplink = "${vpls.uplink}",
            mtu = ${toString vpls.mtu},
            vc_id = ${toString vpls.vcID},
            address = "${vpls.address}",
            bridge = {
              type = "${vpls.bridge.type}",
        '' +
        (let bridge = vpls.bridge; in
        if bridge.type == "learning" then
          let mac = bridge.config.learning.macTable; in
          (indentBlock 4
          ''
            config = {
              ac_table = {
                verbose = ${boolToString mac.verbose},
                timeout = ${toString mac.timeout}
              },
            },
          '')
        else
          "") +
        (indentBlock 2
        ''
          }, --bridge
        '') +
        (indentBlock 2 (tunnelConfig vpls.defaultTunnel)) +
        (optionalString vpls.defaultControlChannel.enable
                        (indentBlock 2 (ccConfig vpls.defaultControlChannel))) +
        (indentBlock 2
        ''
          shmem_dir = "${cfg-snabb.shmemDir}",
          ac = {
        '') +
        (indentBlock 4
         ((mkConfigIterator "attachmentCircuits" acConfig) vpls)) +
        (indentBlock 2
        ''
          },
          pw = {
        '') +
        (indentBlock 4 ((mkConfigIterator "pseudowires" pwConfig) vpls)) +
        ''
            }, -- pw
          }, -- vpls ${name}
        '';

      addressFamiliesConfig = conf:
        ''
          afs = {
        '' +
        (if hasAttr "ipv6" conf.addressFamilies then
            let ipv6 = conf.addressFamilies.ipv6; in
            (indentBlock 2
             ''
               ipv6 = {
                 address = "${ipv6.address}",
                 next_hop = "${ipv6.nextHop}",
             '') +
             optionalString (ipv6.nextHopMacAddress != null)
               (indentBlock 4
                ''neighbor_mac = "${ipv6.nextHopMacAddress}",'' + "\n") +
             (indentBlock 2
             ''
                 neighbor_nd = ${boolToString ipv6.enableInboundND},
               },
             '')
          else
            throw ("no valid address family found for"
                    + " subinterface ${subint}")) +
        ''}, -- afs'';

      vlansConfig = conf:
        ''
          {
            description = "${conf.description}",
            vid = ${toString conf.vid},
        '' +
        optionalString (conf.addressFamilies != null)
          (indentBlock 2 ''${addressFamiliesConfig conf}'' + "\n") +
        ''
          }, -- vlan
        '';

      interfaceConfig = intf:
        let
          driver = intf.driver;
          intfSnabb = findSingle (s: s.name == intf.name) null null
                                 cfg-snabb.interfaces;
          subIntfs = intf.subInterfaces;
        in if intfSnabb != null then
             ''
               {
                 name = "${intf.name}",
                 ${optionalString (intf.description != null)
                     ''description = "${intf.description}",''}
                 driver = {
                   module = require("${driver.path}").${driver.name},
                   config = {
                     pciaddr = "${intfSnabb.pciAddress}",
                     ${optionalString driver.config.snmpEnable
                         ''snmp = { directory = "${cfg-snabb.shmemDir}" }''}
                   },
                 },
                 mtu = ${toString intf.mtu},
             '' +
             optionalString (intf.macAddress != null)
               (indentBlock 2 ''mac = "${intf.macAddress}",'' + "\n") +
             optionalString (intf.addressFamilies != null)
               (indentBlock 2 ''${addressFamiliesConfig intf}'' + "\n") +
             (indentBlock 2
             ''
               trunk = {
                 enable = ${boolToString intf.trunk.enable},
                 encapsulation = ${
                   let enc = intf.trunk.encapsulation; in
                   if (enc == "dot1q" || enc == "dot1ad") then
                     ''"${enc}"''
                   else
                     enc},
                 vlans = {
             '') +
             ((indentBlock 6 ((mkConfigIterator "vlans" vlansConfig)
                                                intf.trunk))) +
             ''
                   }, -- vlans
                 }, -- trunk
               }, -- interface ${intf.name}
             ''
           else
             throw ("L2VPN: the interface named ${intf.name} is not"
                    + " declared in services.snabb.interfaces");

      instanceConfig = name: config:
        let
          uplink = config.uplink;
        in pkgs.writeText "l2vpn-${name}"
         (''
            return {
              interfaces = {
          '' +
          (indentBlock 4 ((mkConfigIterator "interfaces" interfaceConfig)
                                            cfg)) +
          (indentBlock 2
          ''
            }, -- interfaces
            vpls = {
          '') +
          (indentBlock 4 ((mkConfigIterator "vpls" vplsConfig) config)) +
          ''
              } -- vpls
            }
          '');

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

    ## Add our sub-interfaces to services.snabb.subInterfaces
    services.snabb.subInterfaces = let
      subIntfNames = intf:
        map (vlan: intf.name + "." + toString vlan.vid) intf.trunk.vlans;
    in
      concatLists (map subIntfNames cfg.interfaces);

    ## Register the SNMP sub-agent that handles the L2VPN-related
    ## MIBs with the SNMP daemon.
    services.snmpd.agentX.subagents = mkIf cfg-snmpd.enable [
      rec {
        name = "pseudowire";
        executable = pkgs.snabbSNMPAgents + "/bin/${name}";
        args = ("--mibs-dir=${pkgs.snabbPwMIBs} "
                + "--shmem-dir=${cfg-snabb.shmemDir}");
      }
    ];

    ## Generate the list of IPv6 addresses and associated next-hops
    ## that need to be announced as static routes through BGP.  There
    ## is no point in making these advertisements dynamic,
    ## e.g. withdraw them when the VPN service is down, since there is
    ## nowhere else these packets could go.
    services.exabgp.staticRoutes = mkIf cfg-exabgp.enable (let
      nextHopFromIfConfig = ifSpec:
        let
          intfs = cfg.interfaces;
          parts = splitString "." ifSpec;
          nParts = (count (x: true) parts);
          getAddress = intf:
            if hasAttr "addressFamilies" intf then
              intf.addressFamilies.ipv6.address
            else
              throw ("interface ${ifSpec} is L2 when L3 "
                     + "was expected");

        in
          if (nParts >= 1 && nParts <= 2) then
            let
              name = elemAt parts 0;
              intf = findSingle (e: e.name == name)
                                null null intfs;
            in
              if intf != null then
                if nParts == 1 then
                  getAddress intf
                else
                  let
                    vid = elemAt parts 1;
                    trunk = intf.trunk;
                    vlan = findSingle (e: toString(e.vid) == vid)
                                      null null trunk.vlans;
                  in
                    if vlan != null then
                      getAddress vlan
                    else
                      throw ("sub-interface ${vid} of "
                             + "${name} does not exist")
              else
                throw "interface ${name} does not exist"
          else
            throw "illegal interface specifier ${ifSpec}"
      ;

      mkRoute = vpls:
        { route = "${vpls.address}/128";
          nextHop = nextHopFromIfConfig vpls.uplink; };

      mkRoutes = instance:
        map (vpls: mkRoute vpls) (mapAttrsToList (name: value: value)
                                                 instance.vpls);

    in flatten (map mkRoutes (mapAttrsToList (name: value: value)
                                             cfg.instances)));

  }; # config
}
