{ config, pkgs, lib, ... }:

with lib;
with (import ../../../../lib/devices.nix lib);

let
  activeModel = findActiveModel config.services.snabb.devices false;
in
{
  imports = [ ./lcd4linux.nix ];

  config = mkIf ((! isNull activeModel) && (elem "FWA32xx" activeModel.modelSet.classes)) {
    services.lcd4linux = {
      enable = true;
    };
  };
}
