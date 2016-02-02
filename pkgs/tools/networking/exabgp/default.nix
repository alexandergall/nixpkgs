{ stdenv, fetchgit, pkgs, pythonPackages }:

pythonPackages.buildPythonPackage {
  name = "exabgp-3.4";
  src = fetchgit {
    url = "https://github.com/Exa-Networks/exabgp.git";
    sha256 = "06ry0a83yav2pklzybl10llhcgyym5zb4afgh5siphsiklhwvr4c";
    rev = "0ca068b62cbb6871d1158f28570b11439b60818c";
  };
  ## FIXME: dependencies, propagated build inputs
  ## FIXME: add meta
}
