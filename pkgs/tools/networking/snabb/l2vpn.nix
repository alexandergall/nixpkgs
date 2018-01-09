{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideDerivation (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v9";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "0jdp704bmcxzpk0jny7pysmphf2qkpnppggcsanad1hgsym2v9wp";
  };
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
 })
