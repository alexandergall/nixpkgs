{ pkgs, fetchgit }:

with pkgs;

## Override the standard package to fetch the
## "vpn" topic branch.
snabbswitch.overrideDerivation (origAttrs: {
  name = "snabbswitch-vpn";
  src = fetchgit {
    url = "https://github.com/alexandergall/snabbswitch.git";
    sha256 = "106gj0vq93ww7r84cp5ff3kaac53gabcwndpnz5kbiy7rg6pzllb";
    rev = "a4acb5f8c098b7b73c33de4f5a4efb02f463f734";
    #fetchSubmodules = true;
    #leaveDotGit = true;
    #deepClone = true;
  };
  buildInputs = origAttrs.buildInputs ++ [ git ];
  PREFIX = "./";
 })
