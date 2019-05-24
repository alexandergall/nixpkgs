{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideAttrs (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v15";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "0phzhh2q2xbq66sy5h0h8289jas1585xdyfj7jldwy5bnhkn97gy";
  };
  makeFlags = [ "XCFLAGS=-DLUAJIT_USE_PERFTOOLS" ];
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
})
