# Usage:
# $ NIXOS_CONFIG=`pwd`/nixos/modules/virtualisation/cloud-image.nix nix-build '<nixpkgs/nixos>' -A config.system.build.cloudImage

{ config, lib, pkgs, ... }:

with lib;

{
  system.build.cloudImage = import ../../lib/make-disk-image.nix {
    inherit pkgs lib config;
    partitioned = true;
    diskSize = 1 * 1024;
    configFile = pkgs.writeText "configuration.nix"
      ''
        {
          imports = [ <nixpkgs/nixos/modules/virtualisation/cloud-image.nix> ];
        }
      '';
  };

  imports = [
    ../profiles/qemu-guest.nix
    ../profiles/headless.nix
  ];

  fileSystems."/".device = "/dev/disk/by-label/nixos";

  boot.kernelParams = [ "console=ttyS0" ];
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.timeout = 0;

  # Allow root logins
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "without-password";

  services.cloud-init.enable = true;

}
