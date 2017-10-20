{ stdenv, fetchFromGitHub, autoconf, automake, libtool, audit,
  pam_tacplus, pam_tacplus_map, glibc}:

stdenv.mkDerivation rec {
  name = "libnss-tacplus";

  src = fetchFromGitHub {
    owner = "daveolson53";
    repo = "${name}";
    rev = "19008ab68d9d504aa58eb34d5f564755a1613b8b";
    sha256 = "1nsyaygpvm7fc4z02rdsqw3fi1i23hh4g1jcdm03ivm4616d107f";
  };

  preConfigure = "./auto.sh";

  patchPhase = ''
    substituteInPlace Makefile.am \
      --replace "LIBC_VERS = \$(shell ls /lib/" "LIBC_VERS = \$(shell ls ${glibc.out}/lib/" \
      --replace "NSS_VERS = \$(shell ls /lib/" "NSS_VERS = \$(shell ls ${glibc.out}/lib/"
    '';

  buildInputs = [ autoconf  automake libtool audit pam_tacplus pam_tacplus_map glibc ];
}
