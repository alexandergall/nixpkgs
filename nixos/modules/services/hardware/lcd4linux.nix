{ config, pkgs, lib, ...}:

with lib;

let
  cfg = config.services.lcd4linux;
  configFile = with cfg.display; pkgs.writeText "lcd4linux-config" ''
    Display ${name} {
      Driver '${driver}'
      Model '${model}'
      Port '${port}'
      Speed ${toString speed}
      Size ${size}
      Brightness ${toString brightness}
      Icons ${toString icons}
    }
    ${optionalString (cfg.literalConfig != null) cfg.literalConfig}
  '';
in
{

  options = {
    services.lcd4linux = {
      enable = mkOption {
        default = false;
        description = ''
          Whether to start the LCD4linux daemon.
        '';
      };
      display = {
        name = mkOption {
          type = types.str;
          description = ''
            The name of the Display section to generate
          '';
        };
        driver = mkOption {
          type = types.str;
          description = ''
            The Driver field of the Display section.
          '';
        };
        model = mkOption {
          type = types.str;
          description = ''
            The Model field of the Display section.
          '';
        };
        port = mkOption {
          type = types.str;
          description = ''
            The Port field of the Display section.
          '';
        };
        speed = mkOption {
          type = types.int;
          description = ''
            The Speed field of the Display section.
          '';
        };
        size = mkOption {
          type = types.str;
          description = ''
            The Size field of the Display section.
          '';
        };
        brightness = mkOption {
          type = types.int;
          description = ''
            The Brightness field of the Display section.
          '';
        };
        icons = mkOption {
          type = types.int;
          description = ''
            The Icons field of the Display section.
          '';
        };
      };
      literalConfig = mkOption {
        type = types.nullOr types.str;
        description = ''
          Literal LCD4Linux configuration statements except Display,
          which is generated from <option>services.lcd4linux.display</option>
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    ## LCD4Linux insists that the configuration file
    ## is only readable by the owner
    environment.etc."lcd4linux.conf" = {
      source = configFile;
      mode = "0400";
    };

    systemd.services.lcd4linux = {
      description = "LCD4linux Daemon";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "@${pkgs.lcd4linux}/bin/lcd4linux lcd4linux";
        Type = "forking";
        PIDFile = /var/run/lcd4linux.pid;
      };
    };
  };

}
