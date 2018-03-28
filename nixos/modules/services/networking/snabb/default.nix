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

      ## FIXME: do we need this?
      stateDir = mkOption {
        type = types.str;
        default = "/var/lib/snabb";
        example = literalExample ''"/var/lib/snabb"'';
        description = ''
          Path to a directory where Snabb processes can store persistent state.
        '';
      };

      ## FIXME: this will probably go away once the Snabb MIB stuff is moved
      ## to the new-style core/shm framework.
      shmemDir = mkOption {
        type = types.str;
        default = "/var/lib/snabb/shmem";
        example = literalExample ''"/var/run/snabb"'';
        description = ''
          Path to a directory where Snabb processes create shared memory
          segments.  This is used by the legacy lib/ipc/shmem mechanism.
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
      ##   description
      ##     A string that will be used as description in the systemd
      ##     service definition
      ##   programName
      ##     The name of the Snabb program to run
      ##   programOptions
      ##     A string of command-line options passed to the program
      ##     being run.  If the string is empty, the global option
      ##     config.services.snabb.programOptions will be used
      ##     instead
      ##   programArgs
      ##     A string of command-line arguments passed to the program
      ##     being run
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

  config = mkIf cfg.enable {
    systemd.services = let
      mkService = let
        snmpdService = optional snmpd-cfg.enable "snmpd.service ";
      in instance:
        nameValuePair
          instance.name
          { inherit (instance) description;

            wantedBy = [ "multi-user.target" ];
            requires = snmpdService;
            before = snmpdService;

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
              User = "root";
              Group = "root";
            };
          };
    in listToAttrs (map mkService (partition (inst: inst.enable)
                                             cfg.instances).right);

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
