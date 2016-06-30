{ pkgs, fetchgit }:

with pkgs;

stdenv.mkDerivation rec {
  name = "snabb-PW-MIBs";
  src = fetchgit {
    url = "https://github.com/alexandergall/snabb-snmp-subagent.git";
    sha256 = "0jarxsdsdmsrlnd12hmczpwczds0zbncf0pyai32qjn1vbx9q3as";
    rev = "bbf56533313dbb62f5e938fefcdd3e98292233d2";
  };
  builder = writeScript "copy-mibs" ''
    source $stdenv/setup
    mkdir $out
    cp $src/mibs/* $out
  '';
}
