{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
## To get the hash use:
##   nix-prefetch-url --unpack --name snabb-${version} \
##      https://github.com/snabbco/snabb/archive/${version}.tar.gz
snabb.overrideAttrs (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v14";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "19p55n9ilwlnjkbn9mgzxgrf84w4iamm5qwyq81a52dz0mh6m8j3";
  };
  makeFlags = [ "XCFLAGS=-DLUAJIT_USE_PERFTOOLS" ];
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
})
