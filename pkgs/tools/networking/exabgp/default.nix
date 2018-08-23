{ stdenv, fetchgit, pkgs, pythonPackages }:

pythonPackages.buildPythonPackage {
  name = "exabgp-3.4";
  src = fetchgit {
    url = "https://github.com/Exa-Networks/exabgp.git";
    sha256 = "0r12ij2nvc9s718ji004c4sgmv40q52b366v2hhy52qn0dx50c2j";
    rev = "0ca068b62cbb6871d1158f28570b11439b60818c";
  };
  ## FIXME: dependencies, propagated build inputs
  ## FIXME: add meta
}
