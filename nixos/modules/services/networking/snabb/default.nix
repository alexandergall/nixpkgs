### This is a proposal for an extensible module to define all aspects
### of a Snabb program.  This module collects the properties common to
### all programs.
###
### Each program (snabbnfv, packetblaster, l2vpn etc.)  is defined by
### a submodule located in the "programs/<program_name>" subdirectory
### and hooks into the main module through the option
### services.snabb.programs.<program_name>.  This allows each program
### to define its own NixOS options and supports the definition of
### independent instances of the program.
###
### The implementation of a submodule populates
### services.snabb.instances for every instance of the program that it
### represents.  Finally, the implementation of the main module
### creates a systemd service for each of them.
###
### This is a first shot at how this could be done.  Comments are
### very welcome :)
###
### Handling of programs that use ptree:
###
### The goal is to allow reconfiguration without restaring a process.
### Uses directory hierarchy in <stateDir>
###
###   instStateDir = <stateDir>/services/<program>/<instance>
###
### The service for an instance must not depend on anything in the Nix
### store that changes when the configuration is updated.  The service
### must assume that its configuration is located in <instStateDir>/config
###
### Helper service to manage ptree-based services.  A ptree service must
### apply "Wants" and "After" to the helper.
###
###   * Depends on service configurations of all ptree services in the
###     Nix store
###   * Gets restarted whenever a configuration changes after
###     a "nixos-rebuild"
###   * One config file per service (too restrictive?)
###
### When the helper is started
###
###   * Store the updated config files in <instStateDir>/config
###   * If a service is already running
###      * Get the PID from <instStateDir>/master.pid
###      * Execute "snabb config <PID> load <instStateDir>/config
###

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.snabb;
  snmpd-cfg = config.services.snmpd;
in

{

  ###### interface

  ## Snabb programs are implemented as sub-modules.
  imports = [ ./programs/l2vpn ];

  options = {
    services.snabb = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable the Snabb service.  When disabled, no instance
          will be started.  When enabled, individual instances can be
          enabled or disabled independently.
        '';
      };

      pkg = mkOption {
        type = types.package;
        default = pkgs.snabb;
        example = literalExample ''pkgs.snabbL2VPN'';
        description = ''
          The package that provides the Snabb switch software, depending on
          which feature set is desired.
        '';
      };

      programOptions = mkOption {
        type = types.str;
        default = "";
        example = literalExample ''-jv=dump'';
        description = ''
          Default command-line options passed to all service instances.
        '';
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/run/snabb";
        description = ''
          Path to a directory where Snabb processes can store persistent state.
        '';
      };

      shmemDir = mkOption {
        type = types.str;
        default = "/var/run/snabb/snmp";
        description = ''
          Path to a directory where Snabb processes create shared memory
          segments for SNMP.  This is used by the legacy lib/ipc/shmem mechanism.
        '';
      };

      snmp = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Whether to enable SNMP for interfaces.  Currently, SNMP is enabled
            unconditionally for pseudowires.
          '';
        };
        interval = mkOption {
          type = types.int;
          default = 5;
          description = ''
            The interval in seconds in which the SNMP objects exported
            via shared memory segments to the SNMP sub-agents are
            synchronized with the underlying data sources such as
            interface counters.
          '';
        };
      };

      devices = mkOption {
        default = {};
        example = literalExample ''
          {
            advantech = {
              FWA3230A = {
                interfaces = {
                  name = "GigE1/0";
                  nicConfig = {
                    pciAddress = "0000:0c:00.0";
                    driver = {
                      path = "apps.inten.intel1g";
                      name = "Intel1g";
                    };
                  };
                };
              };
            };
          }
        '';
        description = ''
          List of supported devices by vendor and model.  The model
          descriptions contain a list of physical interfaces which
          defines their names and driver configurations.  Exactly one
          vendor/model can be designated to be the active device by
          setting its enable option to true. The high-level interface
          configurations in <option>services.snabb.interfaces</option>
          refer to these definitions by name.
        '';
        type = types.attrsOf (types.attrsOf (types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Whether to enable the vendor/model-specific
                configuration.  Only one vendor/model can be enabled.
              '';
            };
            classes = mkOption {
              type = types.listOf types.str;
              default = [];
              description = ''
                A list of arbitrary strings that can be used to
                identify models with common properties.
              '';
            };
            interfaces = mkOption {
              default = [];
              description = ''
                List of per-model interface definitions.
              '';
              type = types.listOf (types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    default = null;
                    example = "TenGigE0/0";
                    description = ''
                      The name of the interface.  All references to
                      this interface must use this name.
                    '';
                  };
                  nicConfig = mkOption {
                    type = types.nullOr (types.submodule
                             (import ./modules/nic-config.nix
                                     { inherit lib; }));
                    default = null;
                    description = ''
                      The low-level configuration of the interface.
                    '';
                };
                };
              });
            };
          };
        }));
      };
      interfaces = mkOption {
        default = [];
        example = literalExample
          ''
            [ {
                name = "TenGigE0/0";
                description = "VPNTP uplink";
                mtu = 1514;
                addressFamilies = {
                  ipv6 = {
                    address = "2001:db8:0:1:0:0:0:2";
                    nextHop = "2001:db8:0:1:0:0:0:1";
                  };
                };
                trunk = { enable = false; };
              }
              {
                name = "TenGigE0/1";
                description = "VPNTP uplink";
                mtu = 9018;
                trunk = {
                  enable = true;
                  encapsulation = "dot1q";
                  vlans = [
                    {
                      description = "AC";
                      vid = 100;
                    }
                    {
                      description = "VPNTP uplink#2";
                      vid = 200;
                      addressFamilies = {
                        ipv6 = {
                          address = "2001:db8:0:2:0:0:0:2";
                          nextHop = "2001:db8:0:2:0:0:0:1";
                        };
                      };
                    }
                  ];
                };
              }
              { name = "Tap1";
                description = "AC";
                nicConfig = {
                  driver = {
                    path = "apps.tap.tap";
                    name = "Tap";
                    literalConfig = "Tap1";
                  };
                };
                mtu = 1514;
              }
            ]
          '';
        description = ''
          A list of interface configurations.  If the nicConfig option
          is not present, then name must refer to an interface defined
          in the vendor/model description referred to by the
          <option>services.snabb.device</option> option.  That
          definition must have a nicConfig attribute which will be
          used for the low-level configuration of the interface.
        '';
        type = types.listOf (types.submodule (import ./modules/interface.nix
                                                     { inherit lib; }));
      };
      subInterfaces = mkOption {
        default = [];
        description = ''
          A list of names of sub-interfaces for which additional ifIndex
          mappings will be created.  This is a private option and is
          populated by the program modules.
        '';
      };

      ## This array is populated by the program modules.  It is used to
      ## generate systemd services in the implementation below.  Each entry
      ## must define he following attributes:
      ##
      ##   name
      ##     A string that will be used as identifier of the service
      ##     in the config.systemd.services attribute set
      ##   enable
      ##     A boolean that indicates whether the systemd service should
      ##     actually be created or not
      ##   usePtreeMaster
      ##     Whether to use the ptree master service to reload a running
      ##     instance
      ##   description
      ##     A string that will be used as description in the systemd
      ##     service definition
      ##   programName
      ##     The name of the Snabb program to run
      ##   programInstanceName
      ##     The name of the instance of the program
      ##   programOptions
      ##     A string of command-line options passed to the program
      ##     being run.  If the string is empty, the global option
      ##     config.services.snabb.programOptions will be used
      ##     instead
      ##   programArgs
      ##     A string of command-line arguments passed to the program
      ##     being run
      ##   programConfig
      ##     Configuration file, used if usePtreeMaster is true
      ##   restartTriggers
      ##     Arbitrary list of items that cause the service to be restarted
      ##     when any of them changes
      instances = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = ''
          Private option used by Snabb program sub-modules.
          Do not use in regular NixOS configurations.
        '';
      };

    };
  };

  ###### implementation

  config =
    let
      l2vpnCfg = cfg.programs.l2vpn;
      enabledInstances = filter (inst: inst.enable) cfg.instances;
      l2vpnInstances = filter (inst: inst.programName == "l2vpn") enabledInstances;
      ipsecEnabledTransports = filterAttrs (n: v: v.ipsec.enable) l2vpnCfg.transports;
      ipsecPeersForInstance = inst:
        let
          transportsForPeer = peer:
            filterAttrs (n: v: v.remote.peer == peer) ipsecEnabledTransports;
          peers = unique (mapAttrsToList (n: v: v.remote.peer) ipsecEnabledTransports);
        in listToAttrs (map (peer: nameValuePair peer (transportsForPeer peer)) peers);
      ipsecPeers = fold (a: b: a // b) {} (map ipsecPeersForInstance l2vpnInstances);
      ipsecEnable = length (attrNames ipsecPeers) > 0;
    in mkIf cfg.enable {
      assertions = [
        { assertion = length l2vpnInstances == 0 ||
                      length (attrNames l2vpnCfg.peers.local) == 1;
          message = "Local L2VPN peer missing or not unique";
        }
        { assertion = ipsecEnable -> (
            let
              localPeer = elemAt (attrValues l2vpnCfg.peers.local) 0;
            in
              localPeer.ike != null
          );
          message = "IPsec not enabled for local peer";
        }
      ];

      systemd.services = let
        mkService = let
          snmpdService = optional snmpd-cfg.enable "snmpd.service ";
        in instance:
          let
            ptreeMasterService = optional instance.usePtreeMaster "snabb-ptree-master.service";
          in
          nameValuePair
            instance.name
            { inherit (instance) description;

              wantedBy = [ "multi-user.target" ];
              wants = ptreeMasterService;
              requires = snmpdService;
              before = snmpdService;
              after = ptreeMasterService;

              restartTriggers = [ instance.restartTriggers ];

              preStart = ''
                for d in ${cfg.stateDir} ${cfg.shmemDir}; do
                  [ -d $d ] || mkdir -p $d
                done
              '';

              serviceConfig = {
                ExecStart = "@${cfg.pkg}/bin/snabb snabb ${instance.programName}"
                               + (if instance.programOptions != "" then
                                     " ${instance.programOptions}"
                                   else
                                     " ${cfg.programOptions}")
                               + " ${instance.programArgs}";
                Type = "simple";
                Restart = "always";
                User = "root";
                Group = "root";
              };
            };
      in listToAttrs (map mkService enabledInstances) //

      ## ptree Master Server
      (let
        ptreeMaster = pkgs.writeShellScriptBin "ptree-master"
          (let
            ptreeInstances = (partition (inst: inst.usePtreeMaster)
                                        enabledInstances).right;
            mkInstanceInfo = instance:
              {
                program = instance.programName;
                name = instance.programInstanceName;
                config = instance.programConfig;
              };
            instancesInfo = map mkInstanceInfo ptreeInstances;
            mkServiceReload = info:
              ''
                doInstance ${info.program} ${info.name} ${info.config}
              '';
          in
          ''
            #!${pkgs.bash}

            set -e
            stateDir=${cfg.stateDir}

            doInstance () {
              prog=$1
              name=$2
              newConfig=$3

              state=$stateDir/$prog/$name
              test -d $state || mkdir -p $state
              config=$state/config
              if ! test -e $config; then
                echo "Installing initial config for $prog/$name"
                ln -s $newConfig $config
              elif ! ${pkgs.diffutils}/bin/diff $config $newConfig >/dev/null; then
                echo "Installing updated config for $prog/$name"
                rm -f $config $config.o
                ln -s $newConfig $config
                if [ -e $state/master.pid ]; then
                  pid=$(cat $state/master.pid)
                  if kill -0 $pid 2>/dev/null; then
                    echo "Reloading service"
                    ${cfg.pkg}/bin/snabb config load $pid $config
                  else
                    rm -f $state/*.pid
                  fi
                fi
              fi
            }
          '' + concatStrings (map mkServiceReload instancesInfo));
      in {
        snabb-ptree-master = {
          description = "Snabb ptree master service";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            ExecStart = "@${ptreeMaster}/bin/ptree-master ptree-master";
            Type = "oneshot";
            User = "root";
            Group = "root";
          };
        };
      }) //

      (if ipsecEnable then
        (let
          mkIPsecServices = child: transport:
            let
              local = transport.local.peer;
              remote = transport.remote.peer;
              initiateScriptName = "initiate-${child}";
              initiateChild = pkgs.writeShellScriptBin initiateScriptName
              ''
                set -e
                PATH=$PATH:${makeBinPath [ pkgs.gawk pkgs.strongswan ] }

                ## Keep restarting indefinitely
                systemctl reset-failed ${child}

                ## Give the Snabb instances some time to set up the
                ## SA files
                sleep 5

                get_id () {
                    echo "$1" | awk '{print $2}' | tr '[#,]' '[  ]'
                }

                purge () {
                    if [ $1 = "child" ] || ! [ $ike_purged ]; then
                        echo "Purging duplicate $1 SA #$2"
                        swanctl --terminate --$1-id $2
                        [ $1 = "ike" ] && ike_purged="true" || true
                    fi
                }

                cleanup_sas () {
                    ## Cleanup duplicate IKE and CHILD SAs.  Duplicates can
                    ## occur because both sides can act as an initiator.
                    ## The Strongswan IKE daemon supplies the Snabb
                    ## process only with the latest CHILD SAs that has
                    ## been established.  Multiple concurrent SAs can
                    ## cause Snabb to use the wrong one.
                    child_id=0
                    swanctl --list-sas | while read line; do
                        if [[ $line =~ ^${remote}: ]]; then
                            new_ike_id=$(get_id "$line")
                            ike_purged=
                            continue
                        fi
                        if [[ $line =~ ${child} ]]; then
                            new_child_id=$(get_id "$line")
                            if [ $child_id -gt 0 ]; then
                                if [ $new_ike_id -eq $ike_id ]; then
                                    if [ $new_child_id -gt $child_id ]; then
                                        purge "child" $child_id
                                        child_id=$new_child_id
                                    else
                                        purge "child" $child_id
                                    fi
                                elif [ $new_child_id -gt $child_id ]; then
                                    purge "ike" $ike_id
                                    ike_id=$new_ike_id
                                    child_id=$new_child_id
                                else
                                    purge "ike" $new_ike_id
                                fi
                            else
                                ike_id=$new_ike_id
                                child_id=$new_child_id
                            fi
                            continue
                        fi
                    done
                }

                while true; do
                    if ! swanctl --list-sas --ike ${remote} | egrep '${child}.*INSTALLED' >/dev/null; then
                        echo "Child SA for ${child} not present"
                        echo "Peer: ${remote}"
                        echo "Current status:"
                        swanctl --list-sas --ike ${remote}

                        echo "Initiating..."
                        swanctl --initiate --child ${child}
                        cleanup_sas

                        echo "New status:"
                        swanctl --list-sas --ike ${remote}
                    fi
                    sleep 5
                done
              '';
              rekeyScriptName = "rekey-${child}";
              rekeyChild = pkgs.writeShellScriptBin rekeyScriptName
              ''
                PATH=$PATH:${makeBinPath [ pkgs.strongswan ] }

                initiator=$(echo -e "${local}\n${remote}" | sort | head -1)

                if [ $initiator = ${local} ]; then
                  echo "Local system ${local} elected for rekeying"
                  if swanctl --list-sas --ike ${remote} | egrep '${remote}.*ESTABLISHED' >/dev/null; then
                    echo "Rekeying CHILD SA ${child}"
                    swanctl --rekey --child ${child}
                  else
                    echo "IKE SA not established, not rekeying"
                    swanctl --list-sas --ike ${remote}
                  fi
                else
                    echo "Remote system ${remote} elected for rekeying"
                fi
              '';
              childService = singleton "${child}.service";
              l2vpnServices = map (inst: inst.name + ".service") l2vpnInstances;

            in singleton (nameValuePair
              child
              { description = "IPsec initiator for child SA ${child}";

                wantedBy = [ "multi-user.target" ];
                wants = [ "strongswan-swanctl.service" ];
                requires = [ "strongswan-swanctl.service" ] ++ l2vpnServices;
                after = [ "strongswan-swanctl.service" ] ++ l2vpnServices;

                serviceConfig = {
                  ExecStart = "${initiateChild}/bin/${initiateScriptName}";
                  Type = "simple";
                  Restart = "always";
                  RestartSec = 1;
                  User = "root";
                  Group = "root";
                };
              }) ++
              singleton (nameValuePair
              (child + "_rekey")
              { description = "IPsec rekey for child SA ${child}";

                wantedBy = [ "multi-user.target" ];
                wants = childService;
                requires = childService;
                after = childService;

                serviceConfig = {
                  ExecStart = "${rekeyChild}/bin/${rekeyScriptName}";
                  Type = "oneshot";
                  User = "root";
                  Group = "root";
                };
              });
        in listToAttrs (flatten (attrValues (mapAttrs mkIPsecServices ipsecEnabledTransports))))
      else
        {});

      systemd.timers = if ipsecEnable then
        (let
          mkIPsecRekeyTimer = child: transport:
            nameValuePair
              (child + "_rekey")
              { description = "IPsec rekey for child SA ${child}";

                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnUnitInactiveSec = transport.ipsec.rekeyTime;
                  OnBootSec = transport.ipsec.rekeyTime;
                };
              };
        in mapAttrs' mkIPsecRekeyTimer ipsecEnabledTransports)
      else
        {};

    ## Configure IKE, IPsec
    services.strongswan-swanctl = mkIf ipsecEnable {
      enable = true;
      strongswan.extraConfig = ''
        charon-systemd {
          plugins {
            kernel-snabb {
              load = 1000
            }
          }
        }
      '';

      swanctl = let
        localPeer = elemAt (attrNames l2vpnCfg.peers.local) 0;
        localCfg = elemAt (attrValues l2vpnCfg.peers.local) 0;
        mkChild = peerName: name: transport: localCfg: peerCfg:
          let
            plen = {
              ipv4 = "/32";
              ipv6 = "/128";
            }.${transport.addressFamily};
          in with import programs/l2vpn/lib.nix config; {
            local_ts = singleton "${(getAddress name "local").address}${plen}";
            remote_ts = singleton "${(getAddress name "remote").address}${plen}";
            mode = "tunnel";
            esp_proposals = singleton transport.ipsec.espProposal;
            rekey_time = transport.ipsec.rekeyTime;
          };
        mkIkePeer = name: transports:
          let
            peerCfg = l2vpnCfg.peers.remote.${name};
          in {
              local_addrs = localCfg.ike.addresses;
              remote_addrs = peerCfg.ike.addresses;
              rekey_time= "${peerCfg.ike.rekeyTime}";

              local.local = {
                auth = "psk";
                id = "${localPeer}";
              };
              remote.${name} = {
                auth = "psk";
                id = "${name}";
              };
              version = 2;
              inherit (peerCfg.ike) proposals;
              children = mapAttrs (childName: transport: mkChild name childName transport localCfg peerCfg)
                                  transports;
            };
        mkSecret = name: config:
          if any (v: v == name) (attrNames ipsecPeers) then
            {
              id."${name}" = "${name}";
              secret = config.ike.preSharedKey;
            }
          else
            {};

      in {
        connections = mapAttrs (peer: transports: mkIkePeer peer transports) ipsecPeers;
        secrets = {
          ike = {
            local = {
              id."local" = "${localPeer}";
              secret = localCfg.ike.preSharedKey;
            };
          } // mapAttrs mkSecret l2vpnCfg.peers.remote;
        };
      };
    };

    ## Strangely, the strongswan-swanctl module does not open these
    ## ports itself.
    networking.firewall = mkIf ipsecEnable {
      allowedUDPPorts = [ 500 4500 ];
    };

    services.snmpd = mkIf snmpd-cfg.enable {
      agentX = {
        commonArgs = let
          isUnique = l:
            length l == length (unique l);
          names = map (s: s.name) cfg.interfaces;
          mkIfIndexTable = pkgs.writeText "snabb-ifindex"
            ''${concatStringsSep "\n"
                                 (imap (i: v: "${v} ${toString i}")
                                       (names ++ cfg.subInterfaces))}'';
        in
          if isUnique names then
            "--ifindex=${mkIfIndexTable}"
          else
            throw "names in services.snabb.interfaces are not unique";

        subagents = [
          rec {
            name = "interface";
            executable = pkgs.snabbSNMPAgents + "/bin/${name}";
            args = "--shmem-dir=${cfg.shmemDir}";
            modulesInclude = [ "-ifTable" ];
          }
        ];
      };

      ## The Snabb SNMP sub-agent uses community "snabb" to read
      ## sysUpTime in order to be independent of the "public" community.
      views.sysUpTime = {
        type = "included";
        oid = ".1.3.6.1.2.1.1.3";
      };
      communities = {
        ro = [ { community = "snabb"; source = "127.0.0.1"; view = "sysUpTime"; } ];
        ro6 = [ { community = "snabb"; source = "::1"; view = "sysUpTime"; } ];
      };
    };
  };

}
