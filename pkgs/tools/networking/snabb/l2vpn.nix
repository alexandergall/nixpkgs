{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideDerivation (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v6";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "1h8y130k88qx1p0ymjp3vi7fkfyxb6aai550hdk09nsxhqg31ngv";
  };
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
 })
