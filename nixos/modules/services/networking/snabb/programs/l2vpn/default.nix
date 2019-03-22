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
  imports = [ ./devices ];

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

      instances = mkOption {
        default = {};
        description = ''
          Set of definitions of L2VPN termination points (VPNTP).
        '';
        example = literalExample ''TBD'';
        type = types.attrsOf (types.submodule {
          options = {

            ### L2VPN instance configuration options

            enable = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Whether to start this VPNTP instance.
              '';
            };

            usePtreeMaster = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Whether this instance should be controlled by the Snabb
                ptree master service to allow dynamic reconfiguration
                without restarting the instance service.
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

            luajitWorker = {
              options = mkOption {
                type = types.listOf types.str;
                default = [];
                description = ''
                  A list of LuaJIT runtime options passed to Snabb worker
                  processes (<option>programOptions</option> apply to the
                  supervisor process only).
                '';
              };
              dump = {
                enable = mkOption {
                  type = types.bool;
                  default = false;
                  description = ''
                    Whether to enable the JIT dump facility.
                  '';
                };
                option = mkOption {
                  type = types.str;
                  default = "";
                  example = "+rs";
                  description = ''
                    The configuration option for the JIT dump facility.
                  '';
                };
                file = mkOption {
                  type = types.str;
                  default = "/tmp/dump-%p";
                  description = ''
                    The full path name of the file to write the dump to.
                    The string "%p" will be replaced with the ID of the
                    worker process.
                  '';
                };
              };
            };

            ipsec = mkOption {
              type = types.attrsOf (types.submodule {
                options = {
                  encryptionAlgorithm = mkOption {
                    type = types.enum [ "aes-gcm-16-icv" ];
                    default = "aes-gcm-16-icv";
                    description = ''
                      The encyption algorithm to use on the selected traffic.
                    '';
                  };
                  trafficSelectors = {
                    addressFamily = mkOption {
                      type = types.enum [ "ipv4" "ipv6" ];
                      default = "ipv6";
                      description = ''
                        The address family to use for this selector.
                      '';
                    };
                    localAddress = mkOption {
                      type = types.str;
                      default = null;
                      example = "2001:DB8:0:1::1";
                      description = ''
                        The address of the local tunnel endpoint within the
                        specified address family.
                      '';
                    };
                    remoteAddress = mkOption {
                      type = types.str;
                      default = null;
                      example = "2001:DB8:0:1::1";
                      description = ''
                        The address of the remote tunnel endpoint within the
                        specified address family.
                      '';
                    };
                  };
                };
              });
              default = {};
              description = ''
                A set of IPsec policies consisting of an encryption
                algorithm and a traffic selector that must match the
                local and remote endpoint addresses of the pseudowires
                that should be protected.
              '';
            };

            vpls = let
              tunnelOption = { maybeNull ? false,
                               default ? { type = "l2tpv3"; },
                               description }: {
                type = (if maybeNull then types.nullOr else id)
                       (mkSubmodule ./tunnel.nix);
                example = literalExample
                  ''
                    { type = "l2tpv3";
                      config.l2tpv3 = {
                        localCookie = "\x00\x11\x22\x33\x44\x55\x66\x77";
                        remoteCookie = "\x00\x11\x22\x33\x44\x55\x66\x77";
                      };
                    }
                  '';
                inherit default description;
              };
              controlChannelOption = { maybeNull ? false,
                                       default ? { heartbeat = 10;
                                                   deadFactor = 3; },
                                       description }: {
                type = (if maybeNull then types.nullOr else id)
                       (mkSubmodule ./control-channel.nix);
                example = literalExample
                  ''
                    { heartbeat = 10;
                      deadFactor = 3; }
                  '';
                inherit default description;
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
                    example = "TenGigE0/0.100";
                    description = ''
                      The name of a L3 interface which is used to send
                      and receive encapsulated packets.  The named
                      interface must exist in the
                      <option>interfaces</option> option of the VPNTP
                      instance.
                    '';
                  };
                  mtu = mkOption {
                    type = types.int;
                    default = null;
                    example = 1514;
                    description = ''
                      The MTU in bytes of the VPLS instance, including
                      the entire Ethernet header (in particular, any
                      VLAN tags used by the client, i.e. "non
                      service-delimiting tags").  The MTU must be
                      consistent across the entire VPLS.  If the
                      control-channel is enabled, this value is
                      announced to the remote pseudowire endpoints and
                      a mismatch of local and remote MTUs will result
                      in the pseudowire being disabled.
                    '';
                  };
                  defaultTunnel = mkOption (tunnelOption {
                    description = ''
                      The default tunnel configuration for pseudowires.  This
                      can be overriden in the per-pseudowire configurations.
                    ''; });
                  defaultControlChannel = mkOption (controlChannelOption {
                    description =
                      ''
                        The default control-channel configuration for
                        pseudowires.  This can be overriden in the
                        per-pseudowire configurations.
                      ''; });
                  bridge = mkOption {
                    default = { type = "learning"; };
                    example = literalExample
                      ''
                        {
                          type = "learning";
                          config.learning = {
                            macTable = {
                              verbose = false;
                              timeout = 30;
                            };
                          };
                        }
                      '';
                    type = mkSubmodule ../../modules/bridge.nix;
                    description = ''
                      The configuration of the bridge module for a
                      multi-point VPN.
                    '';
                  };
                  attachmentCircuits = mkOption {
                    type = types.attrsOf types.str;
                    default = {};
                    example = literalExample
                      ''
                        { ac1 = "TenGigE0/0";
                          ac2 = "TenGigE0/1.100"; }
                      '';
                    description = ''
                      An attribute set that defines all attachment
                      circuits which will be part of the VPLS
                      instance.  Each AC must refer to the name of a
                      L2 interface defined in the
                      <option>interfaces</option> option of the VPNTP
                      instance.
                    '';
                  };
                  pseudowires = mkOption {
                    type = types.attrsOf (types.submodule {
                      options = {
                        addressFamily = mkOption {
                          type = types.enum [ "ipv4" "ipv6" ];
                          default = "ipv6";
                          description = ''
                            The address family to use for this pseudowire.  The
                            uplink assigned to the VPLS instance must be
                            configured as a L3 interface for the same address
                            family.
                          '';
                        };
                        localAddress = mkOption {
                          type = types.str;
                          default = null;
                          example = "2001:DB8:0:1::1";
                          description = ''
                            The address of the local tunnel endpoint within the
                            specified address family.
                          '';
                        };
                        remoteAddress = mkOption {
                          type = types.str;
                          default = null;
                          example = "2001:DB8:0:1::1";
                          description = ''
                            The address of the remote tunnel endpoint within the
                            specified address family.
                          '';
                        };
                        vcID = mkOption {
                          type = types.int;
                          default = 1;
                          description = ''
                            The VC ID assigned to the pseudowire.  The 3-tuple
                            consisting of localAddress, remoteAddrerss and vcID
                            must be unique in this instance of the L2VPN program.
                          '';
                        };
                        tunnel = mkOption (tunnelOption
                          { maybeNull = true;
                            default = null;
                            description = ''
                              The configuration of the tunnel for this pseudowire.
                              This overrides the default tunnel configuration for
                              the VPLS instance.
                            ''; });
                        controlChannel = mkOption (controlChannelOption
                          { maybeNull = true;
                            default = null;
                            description =
                              ''
                                The configuration of the control-channel of this
                                pseudowire.  This overrides the default
                                control-channel configuration for the VPLS instance
                              ''; });
                      };
                    });
                    default = {};
                    example = literalExample
                      ''
                        { pw1 = {
                            address = "2001:db8:0:1::1";
                            tunnel = {
                              type = "gre";
                            };
                            controlChannel = { enable = false; };
                          };
                          pw2 = {
                            address = "2001:db8:0:2::1";
                            tunnel = {
                              type = "l2tpv3";
                            };
                          };
                        }
                      '';
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
          maybePrepend = spaces: line:
            if line != "" then
              concatStrings [ spaces line ]
            else
              line;
        in text:
          let
            lines = splitString "\n" text;
          in concatStringsSep "\n" (map (line: maybePrepend spaces line)
                                        lines);

      subIntfName = intf: vid:
        intf.name + "." + toString vid;

      acConfig = name: ac: ignore:
        ''
          attachment-circuit {
            name "${name}";
            interface "${ac}";
          }
        '';

      tunnelConfig = tunnel:
        ''
          tunnel {
        '' +
        (indentBlock 2
          (if tunnel.type == "l2tpv3" then
            let conf = tunnel.config.l2tpv3; in
             ''
               l2tpv3 {
                 local-cookie "${conf.localCookie}";
                 remote-cookie "${conf.remoteCookie}";
               }
             ''
         else # type "gre"
           ''
             gre {}
           '')) +
        ''
          }
      '';

      ccConfig = cc:
        ''
          control-channel {
            heartbeat ${toString cc.heartbeat};
            dead-factor ${toString cc.deadFactor};
          }
        '';

      pwConfig = name: pw: vpls:
        ''
          pseudowire {
            name "${name}";
            vc-id ${toString pw.vcID};
            transport {
              ${pw.addressFamily} {
                local-address "${pw.localAddress}";
                remote-address "${pw.remoteAddress}";
              }
            }
        '' +
        (indentBlock 2
           (if pw.tunnel != null then
              (tunnelConfig pw.tunnel)
           else
              (tunnelConfig vpls.defaultTunnel))) +
        (indentBlock 2
           (let cc = if pw.controlChannel != null then
                        pw.controlChannel
                     else
                        vpls.defaultControlChannel; in
            optionalString cc.enable (ccConfig cc))) +
        ''
          }
        '';

      mkConfigIterator = attr: f:
        set: data:
          if isAttrs set.${attr} then
            concatStrings (map (name: f name (getAttr name set.${attr}) data)
                               (attrNames set.${attr}))
          else
            concatStrings (map (item: f item data) set.${attr});

      vplsConfig = name: vpls: ignore:
        ''
          vpls {
            name "${name}";
            description "${vpls.description}";
            uplink "${vpls.uplink}";
            mtu ${toString vpls.mtu};
            bridge {
              ${vpls.bridge.type} {
        '' +
        (let bridge = vpls.bridge; in
        if bridge.type == "learning" then
          let mac = bridge.config.learning.macTable; in
          (indentBlock 4
          ''
              mac-table {
                verbose ${boolToString mac.verbose};
                timeout ${toString mac.timeout};
              }
            }
          '')
        else
          "{}") +
        (indentBlock 2
        ''
          }
        '') +
        (indentBlock 2
         ((mkConfigIterator "attachmentCircuits" acConfig) vpls null)) +
        (indentBlock 2 ((mkConfigIterator "pseudowires" pwConfig) vpls vpls)) +
        ''
          } // vpls ${name}
        '';

      addressFamilyConfig = afi: afis:
        if afis.${afi} != null then
          let
            afiConfig = afis.${afi};
          in (indentBlock 2
            ''
              ${afi} {
                address "${afiConfig.address}";
                next-hop "${afiConfig.nextHop}";
            '') +
             optionalString (afiConfig.nextHopMacAddress != null)
               (indentBlock 4
                ''
                  next-hop-mac "${afiConfig.nextHopMacAddress}";
                '') +
             (indentBlock 2
             ''
               }
             '')
          else
            "";

      addressFamiliesConfig = conf:
        ''
          address-families {
        '' +
        concatStrings (map (afi: addressFamilyConfig afi conf.addressFamilies) [ "ipv4" "ipv6" ]) +
        ''
          }
        '';

      vlansConfig = conf: intf:
        ''
          vlan {
            description "${conf.description}";
            vid ${toString conf.vid};
        '' +
        (if conf.mtu != null then
          if conf.mtu <= intf.mtu then
            "  mtu ${toString conf.mtu};\n"
          else
            throw ("MTU ${toString conf.mtu} of subinterface "
                   + "${subIntfName intf conf.vid} exceeds MTU "
                   + "${toString intf.mtu} of interface ${intf.name}")
        else
          "") +
        optionalString (conf.addressFamilies != null)
          (indentBlock 2 ''${addressFamiliesConfig conf}'') +
        ''
          }
        '';

      interfaceConfig = intf: ignore:
        with (import ../../lib/devices.nix lib);
        let
          intfSnabb = findSingle (s: s.name == intf.name) null null
                                 cfg-snabb.interfaces;
          nicConfig =
            if intfSnabb.nicConfig != null then
              intfSnabb.nicConfig
            else
              let
                model = findActiveModel cfg-snabb.devices true;
              in
                let
                  i = (findSingle (i: i.name == intf.name) null null
                                  model.modelSet.interfaces);
                 in
                   if i != null then
                     i.nicConfig
                   else
                     throw (''Interface ${intf.name} not defined or not unique for ''+
                            ''device ${model.vendorName}/${model.modelName}'');
          driver = nicConfig.driver;
          subIntfs = intf.subInterfaces;
        in if intfSnabb != null then
             ''
               interface {
                 name "${intf.name}";
                 ${optionalString (intf.description != null)
                     ''description "${intf.description}";''}
                 driver {
                   path "${driver.path}";
                   name "${driver.name}";
             '' +
             (if driver.literalConfig == null then
                if nicConfig.pciAddress != null then
                  (indentBlock 4
                   ''
                     config "{
                       pciaddr = '${nicConfig.pciAddress}',
                     }";'') + "\n" +
                  optionalString (driver.extraConfig != null)
                  (indentBlock 4
                    ''
                      extra-config "${driver.extraConfig}";'') + "\n"
                else
                  throw "missing PCI address for interface ${intf.name}"
              else
                (indentBlock 4
                 ''
                   config "${driver.literalConfig}";'') + "\n") +
             (indentBlock 2 
              ''
                }
                mtu ${toString intf.mtu};'') + "\n" +
             optionalString (intf.mirror != null)
               (indentBlock 2
               ''
                 mirror {
                   rx ${boolToString intf.mirror.rx};
                   tx ${boolToString intf.mirror.tx};
                   type "${intf.mirror.type}";
                 }
               '') + ## TODO: name
             optionalString (intf.addressFamilies != null)
               (indentBlock 2 ''${addressFamiliesConfig intf}'') +
             (indentBlock 2
             ''
               trunk {
                 enable ${boolToString intf.trunk.enable};
                 encapsulation ${intf.trunk.encapsulation};
             '') +
             ((indentBlock 4 ((mkConfigIterator "vlans" vlansConfig)
                                                intf.trunk intf))) +
             ''
                 }
               } // interface ${intf.name}
             ''
           else
             throw ("L2VPN: the interface named ${intf.name} is not"
                    + " declared in services.snabb.interfaces");

      instanceConfig = name: config:
        let
          uplink = config.uplink;
        in pkgs.writeText "l2vpn-${name}"
         (''
            l2vpn-config {
          '' +
          (indentBlock 2
            ''
              snmp {
                enable ${boolToString cfg-snabb.snmp.enable};
                interval ${toString cfg-snabb.snmp.interval};
              }
            '') +
          (indentBlock 2
            ''
              luajit {
            '') +
          (indentBlock 4
            (concatStrings (map (opt: ''option "${opt}";'' + "\n") config.luajitWorker.options))) +
          (indentBlock 4
            (let dump = config.luajitWorker.dump; in
            ''
              dump {
                enable ${boolToString dump.enable};
                option "${dump.option}";
                file "${dump.file}";
              }
            '')) +
          (indentBlock 2
            ''
              }
            '') +
          (let
            ## Select the interfaces referred to by uplinks and acs
            baseInterface = intf:
              elemAt (splitString "." intf) 0;
            refInterfaces =
              (unique (flatten (map (vpls: (singleton (baseInterface vpls.uplink)) ++
                                           (map baseInterface
                                                (attrValues vpls.attachmentCircuits)))
                                    (attrValues config.vpls))));
            ourInterfaces = {
              interfaces = (partition (e: (any (intf: e.name == intf)
                                              refInterfaces)) cfg-snabb.interfaces).right;
            };
          in
          (indentBlock 2 ((mkConfigIterator "interfaces" interfaceConfig)
                                            ourInterfaces null))) +
          (indentBlock 2 ((mkConfigIterator "vpls" vplsConfig) config null)) +
          ''
            }
          '');

      mkL2VPNService = programInstanceName: config: rec {
        name = "snabb-${programName}-${programInstanceName}";
        inherit (config) enable usePtreeMaster;
        inherit programInstanceName;
        description = "Snabb L2VPN termination point ${name}";
        programName = "l2vpn";
        programOptions = optionalString (config.programOptions != null)
                                        config.programOptions;
        programConfig = instanceConfig name config;
        programArgs = if config.usePtreeMaster then
                         let
                           instDir = cfg-snabb.stateDir + "/l2vpn/" + programInstanceName;
                         in
                           "${instDir}/config ${instDir}"
                      else
                        "${programConfig}";
      };
    in map (name: mkL2VPNService name cfg.instances.${name})
       (attrNames cfg.instances);

    ## Add our sub-interfaces to services.snabb.subInterfaces
    services.snabb.subInterfaces = let
      subIntfNames = intf:
        map (vlan: intf.name + "." + toString vlan.vid) intf.trunk.vlans;
    in
      concatLists (map subIntfNames cfg-snabb.interfaces);

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

    ## Generate the list of IP addresses and associated next-hops
    ## that need to be announced as static routes through BGP.  There
    ## is no point in making these advertisements dynamic,
    ## e.g. withdraw them when the VPN service is down, since there is
    ## nowhere else these packets could go.
    services.exabgp.staticRoutes = mkIf cfg-exabgp.enable (let
      nextHopFromIfConfig = ifSpec: afi:
        let
          intfs = cfg-snabb.interfaces;
          parts = splitString "." ifSpec;
          nParts = (count (x: true) parts);
          getAddress = intf: afi:
            if hasAttr "addressFamilies" intf then
              if hasAttr afi intf.addressFamilies then
                intf.addressFamilies.${afi}.address
              else
                throw ("address family ${afi} not enabled "
                       + "on interface ${ifSpec}")
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
                  getAddress intf afi
                else
                  let
                    vid = elemAt parts 1;
                    trunk = intf.trunk;
                    vlan = findSingle (e: toString(e.vid) == vid)
                                      null null trunk.vlans;
                  in
                    if vlan != null then
                      getAddress vlan afi
                    else
                      throw ("sub-interface ${vid} of "
                             + "${name} does not exist")
              else
                throw "interface ${name} does not exist"
          else
            throw "illegal interface specifier ${ifSpec}"
      ;

      mkRoute = vpls: pw:
        let
          addrBits = {
            ipv4 = 32;
            ipv6 = 128;
          };
        in { route = "${pw.localAddress}/${toString addrBits.${pw.addressFamily}}";
             nextHop = nextHopFromIfConfig vpls.uplink pw.addressFamily; };

      mkRoutesForVpls = vpls:
        map (pw: mkRoute vpls pw) (mapAttrsToList (name: value: value)
                                              vpls.pseudowires);

      mkRoutesForInstance = instance:
        map (vpls: mkRoutesForVpls vpls) (mapAttrsToList (name: value: value)
                                                         instance.vpls);

    in flatten (map mkRoutesForInstance (mapAttrsToList (name: value: value)
                                                         cfg.instances)));

  }; # config
}
