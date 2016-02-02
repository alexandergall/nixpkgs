### This is a proposal for an extensible module to define all aspects
### of a Snabb program.  This module collects the properties common to
### all programs.
###
### Each program (snabbnfv, packetblaster, l2vpn etc.)  is defined by
### a submodule located in the "programs/<program_name>" subdirectory
### and hooks into the main module through the option
### services.snabbswitch.programs.<program_name>.  This allows each
### program to define its own NixOS options and supports the definition
### of independent instances of the program.
###
### The implementation of a submodule populates
### services.snabbswitch.instances for every instance of the program
### that it represents.  Finally, the implementation of the main
### module creates a systemd service for each of them.
###
### This is a first shot at how this could be done.  Comments are
### very welcome :)

{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.snabbswitch;
  snmpd-cfg = config.services.snmpd;
in

{

  ###### interface

  ## Snabb programs are implemented as sub-modules.
  imports = [ ./programs/l2vpn ];

  options = {
    services.snabbswitch = {
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
        default = pkgs.snabbswitch;
        example = literalExample ''pkgs.snabbswitchVPN'';
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

      interfaces = mkOption {
        type = types.listOf types.str;
        default = [];
        example = literalExample ''[ "0000:04:00.0" "0000:04:00.1" ]'';
        description = ''
          List of PCI addresses of NICs available for Snabb processes.  Snabb
          programs may use this to check the validity of PCI addresses within
          their own configurations.  The list is also used to generate a static
          mapping to interface indexes in the context of the SNMP interface MIBs.
          For that purpose, the interfaces are numbered sequentially starting from 1.
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
      ##     config.services.snabbswitch.programOptions will be used
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
            after = snmpdService;

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
    in listToAttrs (map mkService (partition (inst: inst.enable) cfg.instances).right);

    services.snmpd.agentX = mkIf snmpd-cfg.enable {
      commonArgs = let
        mkIfIndexTable = pkgs.writeText "snabb-ifindex"
          ''${concatStringsSep "\n" (imap (i: v: "${v} ${toString i}") cfg.interfaces)}'';
      in "--ifindex=${mkIfIndexTable}";

      subagents = [
        rec {
          name = "interface";
          executable = pkgs.snabbSNMPAgents + "/bin/${name}";
          args = "--shmem-dir=${cfg.shmemDir}";
          modulesInclude = [ "-ifTable" ];
        }
      ];
    };

  };

}
