{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.exabgp;
  stateDir = "/var/lib/exabgp";
  pidFile = "/var/run/exabgp.pid";
  mkFamily = conf:
    concatStringsSep "\n" (map (x: "${x.afi} ${x.safi};") conf);

  mkStatic = let
    staticGroup = routes:
      concatStringsSep "\n" (map (x: "route ${x.route} {\nnext-hop ${x.nextHop};\n}") routes);
  in routes:
    optionalString (length routes != 0 || length cfg.staticRoutes != 0)
    ''static {
      ${staticGroup cfg.staticRoutes}
      ${staticGroup routes}
      }'';

  mkNeighbor = conf:
    ''neighbor ${conf.remoteAddress} {
        local-address ${conf.localAddress};
        local-as ${toString conf.localAS};
        peer-as ${toString conf.remoteAS};
        group-updates true;
        ${optionalString (conf.md5 != "") ''md5 "${conf.md5}";''}
        ${optionalString (conf.extraConfig != "") conf.extraConfig}

        family {
          ${mkFamily conf.addressFamilies}
        }

        ${mkStatic conf.staticRoutes}
      }
    '';

  mkProcess = name: conf:
    ''process ${name} {
        run "${conf.run}";
      }'';

  exabgpIni = pkgs.writeText "exabgp-ini" ''
    group default {
      router-id ${cfg.routerID};
      ${concatStringsSep "\n" (map mkNeighbor cfg.neighbors)}
      ${concatStringsSep "\n" (map (name: mkProcess name cfg.processes.${name}) (attrNames cfg.processes))}
    }
  '';

  exabgpEnv = let
    boolToString = value: if value then "true" else "false";
  in cfg: pkgs.writeText "exabgp-env" ''
    [exabgp.api]
    encoder = ${cfg.api.encoder}
    highres = ${boolToString cfg.api.highres}
    respawn = ${boolToString cfg.api.respawn}
    socket = ${cfg.api.socket}

    [exabgp.bgp]
    openwait = ${toString cfg.bgp.openwait}

    [exabgp.cache]
    attributes = ${boolToString cfg.cache.attributes}
    nexthops = ${boolToString cfg.cache.nexthops}

    [exabgp.daemon]
    daemonize = ${boolToString cfg.daemon.daemonize}
    pid = ${cfg.daemon.pid}
    user = ${cfg.daemon.user}

    [exabgp.log]
    all = ${boolToString cfg.log.all}
    configuration = ${boolToString cfg.log.configuration}
    daemon = ${boolToString cfg.log.daemon}
    destination = ${cfg.log.destination}
    enable = ${boolToString cfg.log.enable}
    level = ${cfg.log.level}
    message = ${boolToString cfg.log.message}
    network = ${boolToString cfg.log.network}
    packets = ${boolToString cfg.log.packets}
    parser = ${boolToString cfg.log.parser}
    processes = ${boolToString cfg.log.processes}
    reactor = ${boolToString cfg.log.reactor}
    rib = ${boolToString cfg.log.rib}
    routes = ${boolToString cfg.log.routes}
    short = ${boolToString cfg.log.short}
    timers = ${boolToString cfg.log.timers}

    [exabgp.pdb]
    enable = ${boolToString cfg.pdb.enable}

    [exabgp.profile]
    enable = ${boolToString cfg.profile.enable}
    file = ${cfg.profile.file}

    [exabgp.reactor]
    speed = ${cfg.reactor.speed}

    [exabgp.tcp]
    bind = ${cfg.tcp.bind}
    delay = ${toString cfg.tcp.delay}
    once = ${boolToString cfg.tcp.once}
    port = ${toString cfg.tcp.port}

  '';
in

{

  ###### interface

  options = {

    services.exabgp = let
      staticRouteOption = {
        options = {
          route = mkOption {
            type = types.str;
            default = null;
            example = literalExample ''"2001:DB8::/48"'';
            description = ''
              IPv4 or IPv6 Prefix to advertise.
            '';
          };
          nextHop = mkOption {
            type = types.str;
            default = null;
            example = literalExample ''"2001:DB8::1"'';
            description = ''
              Address of the next-hop for the prefix.
            '';
          };
        };
      };
    in {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to start the ExaBGP daemon.
        '';
      };

      ## ExaBGP configuration options.  The structure is
      ## identical to that of the INI file.
      config = {
        api = {
          encoder = mkOption {
            type = types.enum [ "text" "json" ];
            default = "text";
            description = ''
              Encoder to use with with external API.
            '';
          };
          highres = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to use highres timer in JSON.
            '';
          };
          respawn = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether a helper process should be re-spawned if it dies.
            '';
          };
          socket = mkOption {
            type = types.str;
            default = "";
            description = ''
              Path where a socket for remote control should be created.
            '';
          };
        };

        bgp = {
          openwait = mkOption {
            type = types.int;
            default = 60;
            description = ''
              How many seconds to wait for an OPEN once the TCP session is established.
            '';
          };
        };

        cache = {
          attributes = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to cache all attributes (configuration and wire) for faster parsing.
            '';
          };
          nexthops = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to cache routes next-hops (deprecated: next-hops are always cached).
            '';
          };
        };

        daemon = {
          daemonize = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether we should run in the background.
            '';
          };
          pid = mkOption {
            type = types.str;
            default = "";
            description = ''
              Where to save the pid if daemonzied.
            '';
          };
          user = mkOption {
            type = types.str;
            default = "nobody";
            description = ''
              User to run as.
            '';
          };
        };

        log = {
          all = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to enable "DEBUG" level for all categories.
            '';
          };
          configuration = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to log command parsing.
            '';
          };
          daemon = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to log daemon activity (forking, PID, etc.).
            '';
          };
          destination = mkOption {
            type = types.str;
            default = "stdout";
            ## FIXME: formatting
            description = ''
              Where logging should go.
              syslog (or no setting) sends the data to the local syslog syslog
              host:"location" sends the data to a remote syslog server
              stdout sends the data to stdout
              stderr sends the data to stderr
              "filename" send the data to a file. default ('stdout')
            '';
          };
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether to enable logging.
            '';
          };
          level = mkOption {
            type = types.enum [
             "DEBUG" "INFO" "NOTICE" "WARNING" "ERR" "CRIT" "ALERT" "EMERG"
            ];
            default = "INFO";
            description = ''
              Sysylog-style log level.
            '';
          };
          message = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report changes in route announcement on config reload.
            '';
          };
          network = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report networking information (TCP/IP, network state,...).
            '';
          };
          packets = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report BGP packets sent and received.
            '';
          };
          parser = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report BGP message parsing details.
            '';
          };
          processes = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report handling of forked processes.
            '';
          };
          reactor = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report signal received, command reload.
            '';
          };
          rib = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report change in locally configured routes.
            '';
          };
          routes = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report received routes.
            '';
          };
          short = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to use short log format (not prepended with time,level,pid and source).
            '';
          };
          timers = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to report keepalives timers.
            '';
          };
        };

        pdb = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to start the python interactive debugger on startup.
            '';
          };
        };

        profile = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Whether to enable the profiler.
            '';
          };
          file = mkOption {
            type = types.str;
            default = "";
            description = ''
              Name of the file for the output of the profiler. An
              empty name will log to stdout.
            '';
          };
        };

        reactor = {
          speed = mkOption {
            type = types.str;
            default = "1.0";
            description = ''
              Reactor loop time.  Only use if you know
              what you're dooing.
            '';
          };
        };

        tcp = {
          bind = mkOption {
            type = types.str;
            default = "";
            description = ''
              IP address to bind to (none will use wildacrd).
            '';
          };
          delay = mkOption {
            type = types.int;
            default = 0;
            description = ''
              Start to announce route when the minutes in the
              hours is a modulo of this number.
            '';
          };
          once = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Only one tcp connection attempt per peer (for debuging scripts).
            '';
          };
          port = mkOption {
            type = types.int;
            default = 179;
            description = ''
              Port to bind to.
            '';
          };
        };
      };

      routerID = mkOption {
        type = types.str;
        default = null;
        example = literalExample ''"192.0.24.1"'';
        description = ''
          The router ID for the BGP process expressed as a IPv4 address.
        '';
      };

      neighbors = mkOption {
        type = types.listOf (types.submodule {
          options = {
            localAddress = mkOption {
              type = types.str;
              default = null;
              example = literalExample ''"192.0.24.2"'';
              description = ''
                The local IP address from which to establish the
                BGP session.
              '';
            };

            remoteAddress = mkOption {
              type = types.str;
              default = null;
              example = literalExample ''"192.0.24.3"'';
              description = ''
                The remote IP address to which to establish the
                BGP session.
              '';
            };

            localAS = mkOption {
              type = types.int;
              default = null;
              example = literalExample ''"65535"'';
              description = ''
                The AS number of the local BGP speaker.
              '';
            };

            remoteAS = mkOption {
              type = types.int;
              default = null;
              example = literalExample ''"65534"'';
              description = ''
                The AS number of the remote BGP speaker.
              '';
            };

            md5 = mkOption {
              type = types.str;
              default = "";
              example = literalExample ''md5 = "foobar";'';
              description = ''
                Shared secret for MD5 authentication.
              '';
            };

            addressFamilies = mkOption {
              type = types.listOf (types.submodule {
                options = {
                  afi = mkOption {
                    type = types.enum [ "ipv4" "ipv6" ];
                    default = "ipv6";
                    example = literalExample ''"ipv6"'';
                    description = ''
                      BGP address family identifier ("ipv4" or "ipv6").
                    '';
                  };
                  safi = mkOption {
                    type = types.enum [ "unicast" ];
                    default = "unicast";
                    example = literalExample ''"unicast"'';
                    description = ''
                      BGP subsequent subsequent address family identifier ("unicast")
                    '';
                  };
                };
              });
              default = [];
              description = ''
                List of AFI/SAFI to advertise to the neighbor.
              '';
            }; # addressFamilies

            extraConfig = mkOption {
              type = types.str;
              default = "";
              example = literalExample ''auto-flush: true;'';
              description = ''
                Literal configuration statements to be added to the neighbor
                configuration.
              '';
            };

            staticRoutes = mkOption {
              type = types.listOf (types.submodule staticRouteOption);
              default = [];
              example = literalExample
                ''{ route = "2001:DB8::/48";
                    nextHop = "2001:DB8::1"; }'';
              description = ''
                List of static routes to announce to a particular neighbor.
              '';
            };

          };
        });
        default = [];
        description = ''
          List of BGP neighbors.
        '';

      }; # neighbors

      staticRoutes = mkOption {
        type = types.listOf (types.submodule staticRouteOption);
        default = [];
        example = literalExample
          ''[ { route = "2001:DB8::/48";
                nextHop = "2001:DB8::1"; } ]'';
        description = ''
          List of static routes to announce to all neighbors.
        '';
      };

      processes = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            run = mkOption {
              type = types.str;
              default = null;
              example = literalExample ''"/tmp/foo.sh"'';
              description = ''
                Path to the program to run as a ExaBGP process.
              '';
            };
          };
        });
        default = {};
        description = ''
          Attribute set which defines "process" clauses in the ExaBGP
          groupe configuration.
        '';
      }; # processes
    };
  }; # options

  ###### implementation

  config = mkIf cfg.enable {

    ## Create services for snmpd itself and all configured subagents
    systemd.services.exabgp = {
      description = "ExaBGP Daemon";

      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -m 0755 -p ${stateDir}
      '';

      serviceConfig = {
        ExecStart = "@${pkgs.exabgp}/bin/exabgp exabgp --env ${exabgpEnv cfg.config} ${exabgpIni}";
        Type = "simple";
        PIDFile = "${pidFile}";
      };
    };

    networking.firewall.allowedTCPPorts = [ 179 ];
  };
}
