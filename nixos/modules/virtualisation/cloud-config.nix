# The NixOS configuration used to create the cloud-image and which
# will be installed as /etc/nixos/configuration.nix in the VM

{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    <nixpkgs/nixos/modules/profiles/headless.nix>
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
