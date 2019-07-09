{ pkgs, fetchgit }:

with pkgs;

stdenv.mkDerivation rec {
  name = "snabb-PW-MIBs";
  src = fetchgit {
    url = "https://github.com/alexandergall/snabb-snmp-subagent.git";
    sha256 = "03ls1c8kkgjmqpgnqspkalagk4wlww7kr1s2dpv7gzp3ags4lmrb";
    rev = "7ef50885fbf3f87c6fe333c22e5561fb7d59249c";
  };
  builder = writeScript "copy-mibs" ''
    source $stdenv/setup
    mkdir $out
    cp $src/mibs/* $out
  '';
}
