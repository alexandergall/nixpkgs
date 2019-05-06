{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideAttrs (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v13";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "1b35jsqnjffx1hsrhd8mfw43ssvccv2xz8m61lgmyans6w3nl8gf";
  };
  makeFlags = [ "XCFLAGS=-DLUAJIT_USE_PERFTOOLS" ];
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
})
