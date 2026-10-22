# Upstream .deb, unpatched: the binaries run through nix-ld (fhs-compat.nix),
# which the runtime-downloaded inference engine in ~/.magnitude needs anyway.
{
  dpkg,
  fetchurl,
  lib,
  stdenvNoCC,
  util-linux,
}:

stdenvNoCC.mkDerivation rec {
  pname = "magnitude";
  version = "0.2.10";
  revision = "60";

  src = fetchurl {
    url = "https://github.com/magnitudedev/magnitude/releases/download/%40magnitudedev%2Fcli%40${version}/magnitude-desktop_${version}-${revision}_amd64.deb";
    hash = "sha256-8nix6+GjOyPbEllCGCZYhWKBHRAHdkP18M/SDBLc2H0=";
  };

  nativeBuildInputs = [ dpkg ];

  # Bun-compiled executables break if stripped or patched.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share
    cp -r usr/lib $out/lib
    cp -r usr/share/applications usr/share/icons $out/share
    ln -s $out/lib/magnitude-desktop/resources/magnitude $out/bin/magnitude
    # The app refuses to start unless `launch` hands it the installation lock on fd 9.
    substituteInPlace $out/lib/magnitude-desktop/launch \
      --replace-fail "flock " "${util-linux}/bin/flock " \
      --replace-fail /usr/lib/magnitude-desktop/magnitude $out/lib/magnitude-desktop/magnitude
    ln -s $out/lib/magnitude-desktop/launch $out/bin/magnitude-desktop
    substituteInPlace $out/share/applications/magnitude-desktop.desktop \
      --replace-quiet /usr/bin/ ""
    runHook postInstall
  '';

  meta = {
    description = "Local inference engine for open models";
    homepage = "https://magnitude.dev";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "magnitude";
  };
}
