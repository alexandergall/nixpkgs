{ config, lib, pkgs, ... }:

with pkgs;
with lib;

let

  cfg = config.users.tacplus;

in

{

  ###### interface

  options = {

    users.tacplus = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable authentication against a TACACS+ server.";
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable debugging in the PAM module.";
      };

      server = mkOption {
        default = null;
        type = types.nullOr types.str;
        example = "192.0.0.1";
        description = "The ipv4 address of a TACACS+ server";
      };

      secret = mkOption {
        default = null;
        type = types.nullOr types.str;
        description = "The secret string shared with the server";
      };

      timeout = mkOption {
        default = 10;
        type = types.int;
        description = "The value used to time out transactions with the server";
      };

      extraConfig = mkOption {
        default = "";
        type = types.lines;
        description = ''
          Extra configuration options that will be added verbatim at
          the end of the configuration file.
        '' ;
      };

    };

  };

  ###### implementation

  config = mkIf cfg.enable {

    assertions = [
      { assertion = cfg.server != null;
        message = "Missing TACACS+ server"; }
      { assertion = cfg.secret != null;
        message = "Missing TACACS+ shared secret"; }
    ];

    environment.etc = [
      rec {
        target = "tacplus_servers";
        source = writeText target ''
          server=${cfg.server}
          secret=${cfg.secret}
          timeout=${toString cfg.timeout}
          ${cfg.extraConfig}
        '';
      }
      rec {
        target = "tacplus_nss.conf";
        source = writeText target ''
          include=/etc/tacplus_servers
        '';
      }
    ];

    system.nssModules = singleton nss_tacplus;

    security.pam.services = let
      debug = optionalString cfg.debug "debug";
    in {
      tacplus.text = ''
        #%PAM-1.0
        auth       sufficient   ${pam_tacplus}/lib/security/pam_tacplus.so ${debug} include=/etc/tacplus_servers
        account    sufficient   ${pam_tacplus}/lib/security/pam_tacplus.so ${debug} include=/etc/tacplus_servers login=login service=shell protocol=ssh
        session    sufficient   ${pam_tacplus}/lib/security/pam_tacplus.so ${debug} include=/etc/tacplus_servers login=login service=shell protocol=ssh
      '';
    };

  services.openssh.extraConfig =
    ''
      Match Group tacacs
        PasswordAuthentication yes
    '';

  users = {
    groups = { tacacs = {}; };
    extraUsers.tacacs0 = {
      isNormalUser = true;
      group = "tacacs";
    };
    extraUsers.tacacs15 = {
      isNormalUser = true;
      group = "tacacs";
    };
  };

  security.sudo.extraConfig = ''
      tacacs15 ALL=(ALL:ALL) ALL
        '';

  };
}
