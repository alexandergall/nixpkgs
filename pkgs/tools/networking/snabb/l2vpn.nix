{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "l2vpn" topic branch.
snabb.overrideDerivation (origAttrs: rec {
  name = "snabb-${version}";
  version = "l2vpn-v3";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "${version}";
    sha256 = "1h07ipqzrpb95w7q8l887mr4hqjsd8w6yzl7p575f45rbhschdjs";
  };
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
 })
