# Usage:
# $ NIXOS_CONFIG=`pwd`/nixos/modules/virtualisation/cloud-image.nix nix-build '<nixpkgs/nixos>' -A config.system.build.cloudImage

{ config, lib, pkgs, ... }:

with lib;

let
  configFile = ./cloud-config.nix;
in {
  system.build.cloudImage = import ../../lib/make-disk-image.nix {
    inherit pkgs lib config configFile;
    partitioned = true;
    diskSize = 1 * 1024;
  };

  imports = [ configFile ];
}
