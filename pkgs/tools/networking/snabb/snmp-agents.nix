{ pkgs, fetchgit }:

with pkgs;

buildPerlPackage  rec {
  name = "Snabb-SNMP-0.01";
  src = fetchFromGitHub {
    owner = "alexandergall";
    repo = "snabb-snmp-subagent";
    rev = "65b799d9d3aa8d8cf5a9acfa925d548beac16d9a";
    sha256 = "0409jwxvzzxma2lvkig4nvsq5xi7c4ghdghjd04mchw5wf3jjvn3";
  };
  preConfigure = ''cd subagent'';
  propagatedBuildInputs = with perlPackages; [
    net_snmp NetSNMP SysMMap
  ];
  inherit (pkgs) snabbPwMIBs;
}
