{ pkgs, fetchgit }:

with pkgs;
let

  ## net_snmp is currently built with perl522 to work around a known
  ## problem.  We also force perl522 to be used to build this module
  ## as well as the other dependencies to get the correct INC paths.
  buildPerlPackage = callPackage ../../../development/perl-modules/generic perl522;

  ## Copied from ../../../top-level/perl-packages.nix, don't know how
  ## to override the perl version
  NetSNMP = buildPerlPackage rec {
    name = "Net-SNMP-6.0.1";
    src = fetchurl {
      url = "mirror://cpan/authors/id/D/DT/DTOWN/Net-SNMP-v6.0.1.tar.gz";
      sha256 = "0hdpn1cw52x8cw24m9ayzpf4rwarm0khygn1sv3wvwxkrg0pphql";
    };
    doCheck = false; # The test suite fails, see https://rt.cpan.org/Public/Bug/Display.html?id=85799
  };
  SysMMap = buildPerlPackage rec {
    name = "Sys-Mmap-0.17";
    src = fetchurl {
      url = "mirror://cpan/authors/id/T/TO/TODDR/${name}.tar.gz";
      sha256 = "05lqs8d4qsi1ky2k93h3fj6qf3qn52b86yfvv4n87hqmnnhwyx7x";
    };
    ## FIXME: add meta
  };
in

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
