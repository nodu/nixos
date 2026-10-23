{ autoPatchelfHook
, buildFHSEnvChroot
, dpkg
, fetchurl
, lib
, stdenv
, sysctl
, iptables
, iproute2
, procps
, cacert
, libidn2
, zlib
, wireguard-tools
, libnl
, libcap_ng
, sqlite
, libxslt        # provides xsltproc (arm64 dep since 4.2.1+)
}:

let
  pname = "nordvpn";
  version = "6.0.1";

  arch = if stdenv.hostPlatform.isAarch64 then "arm64"
         else if stdenv.hostPlatform.isx86_64 then "amd64"
         else throw "nordvpn: unsupported platform ${stdenv.hostPlatform.system}";

  hashes = {
    amd64 = "sha256-SYQ+zPNHfLapX9qXMYNcIa+Ittel0EkvuYF31vsDp3k=";
    arm64 = "sha256-7u+ggywbZ8hzvbHGnKVM5eunZEOtT6yBuR1+/oFt3Zo=";
  };

  nordVPNBase = stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url =
        "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_${version}_${arch}.deb";
      hash = hashes.${arch};
    };

    buildInputs = [ libidn2 sqlite stdenv.cc.cc.lib libcap_ng libnl ];
    nativeBuildInputs = [ dpkg autoPatchelfHook ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg --extract $src .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      mv usr/* $out/
      mv var/ $out/
      mv etc/ $out/
      runHook postInstall
    '';
  };

  nordVPNfhs = buildFHSEnvChroot {
    name = "nordvpnd";
    runScript = "nordvpnd";

    # hardcoded path to /sbin/ip
    targetPkgs = pkgs:
      with pkgs; [
        nordVPNBase
        sysctl
        iptables
        iproute2
        procps
        cacert
        libidn2
        zlib
        wireguard-tools
        libxslt     # xsltproc
      ];
  };

in
stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share
    ln -s ${nordVPNBase}/bin/nordvpn $out/bin
    ln -s ${nordVPNfhs}/bin/nordvpnd $out/bin
    ln -s ${nordVPNBase}/share/* $out/share/
    ln -s ${nordVPNBase}/var $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI client for NordVPN";
    homepage = "https://www.nordvpn.com";
    license = licenses.unfree;
    maintainers = with maintainers; [ LuisChDev ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
