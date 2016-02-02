{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.snmpd;
  stateDir = "/var/lib/net-snmp";
  pidFile = "/var/run/snmpd.pid";

  listeningAddressOption = types.submodule {
    options = {
      proto = mkOption {
        type = types.str;
        default = "udp";
        description = ''
          Transport specifier, see snmpd(5), section LISTENING ADDRESSES.
        '';
      };
      address = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          An IPv4 or IPv6 address to listen on.
        '';
      };
      port = mkOption {
        type = types.int;
        default = 161;
        description = ''
          Port to listen on.
        '';
      };
    };
  };

  mkListeningAddressConfig = let
    assembleAddress = { proto, address, port, ... }:
      ''${proto}${optionalString (address != null) (":" + address)}'' +
      ''${optionalString (port != null) ":" + toString port}'';
  in directive: addresses:
    ''${directive} ${concatMapStringsSep "," assembleAddress addresses}'';

  mkView = name: view:
    ''view ${name} ${view.type} ${view.oid}'';

  mkViews = views:
    concatStringsSep "\n" (map (name: mkView name views.${name}) (attrNames views));

  optionalView = c:
    optionalString (c.view != null) (''-V '' + c.view);

  mkCommunityConfig = directive: list:
    concatStringsSep "\n" (map (x: "${directive} ${x.community} ${x.source} ${optionalView x}") list);

  configFile = pkgs.writeText "snmpd.conf" ''
    ${mkListeningAddressConfig "agentAddress" cfg.agentAddresses}
    agentUser ${cfg.user}
    agentGroup ${cfg.group}

    ${mkCommunityConfig "rocommunity" cfg.communities.ro}
    ${mkCommunityConfig "rocommunity6" cfg.communities.ro6}
    ${mkCommunityConfig "rwcommunity" cfg.communities.rw}
    ${mkCommunityConfig "rwcommunity6" cfg.communities.rw6}

    ${if length cfg.agentX.subagents != 0 then ''
      master agentx
      ${mkListeningAddressConfig "agentXSocket" cfg.agentX.socket}
    '' else ""}
    ${mkViews cfg.views}
    ${concatStringsSep "\n" cfg.extraConfig}
  '';

  snmpdFlags = let
    includeOptions = concatMapStringsSep " " (module: "-I ${module}") cfg.modulesInclude;
  in "-Lsd -Lf /dev/null -c ${configFile} ${includeOptions} -p ${pidFile}";

in

{

  ###### interface

  options = {

    services.snmpd = {

      enable = mkOption {
        default = false;
        description = ''
          Whether to start the SNMP daemon.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "snmp";
        example = "snmp";
        description = ''
          The name of the user as which to run the daemon.
        '';
      };

      group = mkOption {
        type = types.str;
        default = "snmp";
        example = "snmp";
        description = ''
          The name of the group as which to run the daemon.
        '';
      };

      views = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            type = mkOption {
              type = types.enum [ "included" "excluded" ];
              default = "included";
              description = ''
                The type of the view, either "included" or "excluded".
              '';
            };
            oid = mkOption {
              type = types.str;
              default = ".";
              description = ''
                The OID associated with the view.
              '';
            };
            ## FIXME: add support for mask
          };
        });
        default = [];
        description = ''
          A set of view definitions.
        '';
      };

      communities = let
        community = mkOption {
          type = types.str;
          default = "public";
          example = "foobar";
          description = ''
            The community string.
          '';
        };
        view = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            The name of a view to apply to this community definition.
          '';
        };
        source4Option = mkOption {
          type = types.str;
          default = "127.0.0.1";
          example = "192.0.2.0/24";
          description = ''
            IPv4 address Prefix.
          '';
        };
        source6Option = mkOption {
          type = types.str;
          default = "::1";
          example = "2001:DB8:1:/64";
          description = ''
            IPv6 address Prefix.
          '';
        };
      in {
        ro = mkOption {
          type = types.listOf (types.submodule {
            options = {
              inherit community view;
              source = source4Option;
            };
          });
          default = [ {} ];
          description = ''
            A list of read-only communities with IPv4 source restrictions.
          '';
        };
        ro6 = mkOption {
          type = types.listOf (types.submodule {
            options = {
              inherit community view;
              source = source6Option;
            };
          });
          default = [ {} ];
          description = ''
            A list of read-only communities with IPv6 source restrictions.
          '';
        };
        rw = mkOption {
          type = types.listOf (types.submodule {
            options = {
              inherit community view;
              source = source4Option;
            };
          });
          default = [ {} ];
          description = ''
            A list of read-write communities with IPv4 source restrictions.
          '';
        };
        rw6 = mkOption {
          type = types.listOf (types.submodule {
            options = {
              inherit community view;
              source = source6Option;
            };
          });
          default = [ {} ];
          description = ''
            A list of read-write communities with IPv6 source restrictions.
          '';
        };
      };

      extraConfig = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          A list of strings that will be copied verbatim into the configuration file.
        '';
      };

      modulesInclude = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ''[ "-ifTable" "hr_system" ]'';
        description = ''
          List of MIB modules to include or exclude (if prefixed with "-").
          See the <literal>-I</literal> option in snmpd(8).
        '';
      };

      agentAddresses = mkOption {
        type = types.listOf listeningAddressOption;
        default = [ { proto = "udp"; address = "127.0.0.1"; port = 161; }
                    { proto = "udp6"; address = "[::1]"; port = 161; } ];
        example = literalExample ''
          [ { proto = "udp"; address = "127.0.0.1"; port = "161"; }
            { proto = "udp6"; address = "[::1]"; port = "161"; } ];
        '';
        description = ''
          Set protocol, address and port on which the daemon will listen for requests.
          See "agentaddress" in snmpd.conf(5).
        '';
      };

      agentX = {
        socket = mkOption {
          type = types.listOf listeningAddressOption;
          default = [ { proto = "tcp6"; address = "[::1]"; port = 705; } ];
          example = ''[ { proto = "tcp6"; address = "[::1}"; port = 705; } ];'';
          description = ''
            Set protocol, address and port on which the daemon will listen for connections from
            agentX sub-agents.
          '';
        };

        commonArgs = mkOption {
          type = types.str;
          default = "";
          example = literalExample ''"--some-opt=foo"'';
          description = ''
            Command-line options common to all subagents.
          '';
        };

        subagents = mkOption {
          type = types.listOf (types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                default = "";
                description = ''
                  The name of the subagent.
                '';
              };
              executable = mkOption {
                type = types.path;
                default = null;
                description = ''
                  The path of the executable that will be run.
                '';
              };
              args = mkOption {
                type = types.str;
                default = "";
                description = ''
                  The command-line arguments to pass to the executable.
                '';
              };
              modulesInclude = mkOption {
                type = types.listOf types.str;
                default = [];
                description = ''
                  A list of modules that will be passed to the snmpd process
                  as options of type "-I" to override built-in MIB modules.
                '';
              };
            };
          });
          default = [];
          description = ''
            A list of subagent definitions.
          '';
        };
      };

    }; # services.snmpd

  }; # options

  ###### implementation

  config = mkIf cfg.enable {

    users.extraGroups."${cfg.group}" = {};

    users.extraUsers = singleton
      { name = cfg.user;
        isSystemUser = true;
        group = cfg.group;
        description = "SNMP daemon user";
        home = stateDir;
      };

    ## Create services for snmpd itself and all configured subagents
    systemd.services = let
      subagentServices = let
        mkSubagentService = agent:
          let
            subagentConfig = pkgs.writeText "${agent.name}.conf" ''
              ${mkListeningAddressConfig "agentXSocket" cfg.agentX.socket}
            '';
          in nameValuePair
            (agent.name + "-snmp-subagent")
            { description = "Snabb SNMP sub-agent ${agent.name}";

              wantedBy = [ "multi-user.target" ];
              requires = [ "snmpd.service" ];
              after = [ "snmpd.service" ];

              preStart = ''
                rm -f ${stateDir}/${agent.name}.conf
                ln -s ${subagentConfig} ${stateDir}/${agent.name}.conf
              '';

              serviceConfig = {
                ExecStart = "@${agent.executable} ${agent.name} ${agent.args} ${cfg.agentX.commonArgs}";
                Type = "simple";
                User = cfg.user;
                Group = cfg.group;
              };
            };
      in listToAttrs (map mkSubagentService cfg.agentX.subagents);
    in {
      snmpd = {
        description = "SNMP Daemon";

        wantedBy = [ "multi-user.target" ];

        preStart = ''
          mkdir -m 0755 -p ${stateDir}
          chown ${cfg.user} ${stateDir}
        '';

        serviceConfig = {
          ExecStart = "@${pkgs.net_snmp}/bin/snmpd snmpd ${snmpdFlags}";
          Type = "forking";
          PIDFile = "${pidFile}";
        };
      };
    } // subagentServices;

    services.snmpd.modulesInclude = concatLists (map (agent: agent.modulesInclude) cfg.agentX.subagents);

    networking.firewall.allowedUDPPorts = [ 161 ];
  };
}
