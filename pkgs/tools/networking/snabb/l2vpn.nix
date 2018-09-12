{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideDerivation (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v10";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "0i1m6nrb5pb8rh4i6p5xazbrnajpr8mhq600gh6pkiv58avnrvbh";
  };
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
 })
