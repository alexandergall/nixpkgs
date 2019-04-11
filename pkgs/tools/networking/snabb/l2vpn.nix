{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideAttrs (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v12";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "09kh4n6xgxpsc2nqqx39mkbvqqm8cyizg2p5rky601hi432b2qqi";
  };
  makeFlags = [ "XCFLAGS=-DLUAJIT_USE_PERFTOOLS" ];
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
})
