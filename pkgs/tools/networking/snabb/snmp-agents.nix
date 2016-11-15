{ pkgs, fetchgit }:

with pkgs;

## nix-prefetch-url --unpack --name Snabb-SNMP-0.01 \
##   https://github.com/alexandergall/snabb-snmp-subagent/archive/${rev}.tar.gz
buildPerlPackage  rec {
  name = "Snabb-SNMP-0.01";
  src = fetchFromGitHub {
    owner = "alexandergall";
    repo = "snabb-snmp-subagent";
    rev = "v1";
    sha256 = "1hdwkpm9ms3fkr61n8i1yhvlc70npd2njk9yncd2hksrb6f3x6hx";
  };
  preConfigure = ''cd subagent'';
  propagatedBuildInputs = with perlPackages; [
    net_snmp NetSNMP SysMMap
  ];
  inherit (pkgs) snabbPwMIBs;
}
