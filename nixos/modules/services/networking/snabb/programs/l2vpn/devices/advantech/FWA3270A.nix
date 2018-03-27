{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.snabb.devices.advantech;
in
{
  imports = [ ./lcd4linux.nix ];

  config = mkIf cfg.FWA3270A.enable {
    services.lcd4linux = {
      enable = true;
    };
  };
}
