{ stdenv, lib, fetchFromGitHub, bash, makeWrapper, git, mysql, diffutils, which, coreutils, procps, nettools }:

stdenv.mkDerivation rec {
  name = "snabb-${version}";
  version = "2016.08";

  src = fetchFromGitHub {
    owner = "snabbco";
    repo = "snabb";
    rev = "v${version}";
    sha256 = "0dl8q5s01y62js62an22h6vla4xf7ln3i2ky06x6p4v23dcffj4p";
  };

  buildInputs = [ makeWrapper ];

  patchPhase = ''
    patchShebangs .

    # some hardcodeism
    for f in $(find src/program/snabbnfv/ -type f); do
      substituteInPlace $f --replace "/bin/bash" "${bash}/bin/bash"
    done

    # We need a way to pass $PATH to the scripts
    sed -i '2iexport PATH=${stdenv.lib.makeBinPath [ git mysql.client which procps coreutils ]}' src/program/snabbnfv/neutron_sync_master/neutron_sync_master.sh.inc
    sed -i '2iexport PATH=${stdenv.lib.makeBinPath [ git coreutils diffutils nettools ]}' src/program/snabbnfv/neutron_sync_agent/neutron_sync_agent.sh.inc
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp src/snabb $out/bin
  '';

  # Dependencies are underspecified: "make -C src obj/arch/sse2_c.o" fails with
  # "Fatal error: can't create obj/arch/sse2_c.o: No such file or directory".
  enableParallelBuilding = false;

  meta = with stdenv.lib; {
    homepage = https://github.com/SnabbCo/snabbswitch;
    description = "Simple and fast packet networking toolkit";
    longDescription = ''
      Snabb Switch is a LuaJIT-based toolkit for writing high-speed
      packet networking code (such as routing, switching, firewalling,
      and so on). It includes both a scripting inteface for creating
      new applications and also some built-in applications that are
      ready to run.
      It is especially intended for ISPs and other network operators.
    '';
    platforms = [ "x86_64-linux" ];
    license = licenses.asl20;
    maintainers = [ maintainers.lukego maintainers.domenkozar ];
  };
}
