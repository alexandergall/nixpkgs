{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideAttrs (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v11";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "1v0jb1pmhkpvvdzsirzvbc5rvnxcm9qnljja9g2jk6nkq0w8s74v";
  };
  makeFlags = [ "XCFLAGS=-DLUAJIT_USE_PERFTOOLS" ];
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
})
