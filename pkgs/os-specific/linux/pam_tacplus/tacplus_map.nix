{ stdenv, fetchFromGitHub, autoconf, autoconf-archive, automake, libtool, audit }:

stdenv.mkDerivation rec {
  name = "libtacplus-map";

  src = fetchFromGitHub {
    owner = "daveolson53";
    repo = "${name}";
    rev = "f18449816e931464734b7116f1b7c2006c55eb99";
    sha256 = "1x8y80bdagsbvnzv97zipq6fcgqhmia020yv9ja4k3varawx5315";
  };

  patches = [ ./libtacplus-map.patch ];

  preConfigure = "./auto.sh";

  configureFlags = [ "--oldincludedir=\${out}/include" ];

  buildInputs = [ autoconf autoconf-archive automake libtool audit ];
}
