{ pkgs, fetchgit }:

with pkgs;

## nix-prefetch-url --unpack --name Snabb-SNMP-0.01 \
##   https://github.com/alexandergall/snabb-snmp-subagent/archive/${rev}.tar.gz
buildPerlPackage  rec {
  name = "Snabb-SNMP-0.01";
  src = fetchFromGitHub {
    owner = "alexandergall";
    repo = "snabb-snmp-subagent";
    rev = "v2";
    sha256 = "1gjd0lnmlqqck3fx1cjb9zhfb65r5nqv4ng22yynrffv20ia7vkm";
  };
  preConfigure = ''cd subagent'';
  propagatedBuildInputs = with perlPackages; [
    net_snmp NetSNMP SysMMap
  ];
  inherit (pkgs) snabbPwMIBs;
}
