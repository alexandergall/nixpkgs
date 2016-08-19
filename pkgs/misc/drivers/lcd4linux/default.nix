{ fetchsvn, stdenv, libtool, automake, autoconf, gettext, pkgconfig, libusb }:

let
  rev = "1203";
in
  stdenv.mkDerivation {
    name = "lcd4linux-svn-r${rev}";
    src = fetchsvn {
      url = "https://ssl.bulix.org/svn/lcd4linux/trunk";
      inherit rev;
      sha256 = "1pkf56mdym11n012g4wgpbq34mdrkdsbv399nnnzzldjc448iyvh";
    };
    buildInputs = [ libtool automake autoconf gettext pkgconfig libusb ];
    preConfigure = ''
      ./bootstrap
    '';
  }
