{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideDerivation (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v8";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "1r8a1qm82zyd7lzzmj8cf0qcydbq99xzgf3sv5aii9ld8jkly9bf";
  };
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
 })
