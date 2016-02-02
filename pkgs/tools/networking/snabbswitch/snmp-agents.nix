{ pkgs, fetchgit }:

with pkgs;

buildPerlPackage  rec {
  name = "Snabb-SNMP-0.01";
  src = fetchgit {
    url = "https://github.com/alexandergall/snabb-snmp-subagent.git";
    sha256 = "1zam6wa7wpcanzyqb42kz2jxsycwkrjvszypn8x38saz33nr1fx7";
    rev = "a648c07a0b4802e4eebd51e8815e442079eb82aa";
  };
  preConfigure = ''cd subagent'';
  propagatedBuildInputs = with perlPackages; [
    net_snmp NetSNMP SysMMap
  ];
  inherit (pkgs) snabbPwMIBs;
}
