{ stdenv, fetchFromGitHub, autoconf, autoconf-archive, automake,
  libtool, pam, openssl, pam_tacplus_map }:

stdenv.mkDerivation rec {
  name = "pam_tacplus";

  src = fetchFromGitHub {
    owner = "daveolson53";
    repo = "${name}";
    rev = "1daa4e34db9de5cb28538b9af7ef2c213886c655";
    sha256 = "0xbpqxkr16bczyc2cjinvqqs8w7m2yckn0kjnxx276pcb8p1yb5d";
  };

  buildInputs = [ pam_tacplus_map autoconf autoconf-archive automake libtool pam openssl ];

  preConfigure = "./auto.sh";

  configureFlags = [ "--oldincludedir=\${out}/include" "--with-openssl=${openssl.dev}" ];
}
