{
  appimageTools,
  lib,
  fetchurl,
}:

let
  version = "3.2.6";
  buildId = "260114cp6zmcvo0";
  arch = "x86_64";
  pname = "sunsama";
  src = fetchurl {
    url = "https://download.todesktop.com/2003096gmmnl0g1/sunsama-${version}-build-${buildId}-${arch}.AppImage";
    hash = "sha512-ro03Uj6P+fBlgWJsn5va018Bj3xtu76VwhFQhuEfdOIf/IvSXaiuON1h3cYkGU2EOwvDkeRPXmJebqfIkgbFNA==";
  };
  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in

appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/sunsama.desktop $out/share/applications/sunsama.desktop
    install -Dm444 {${appimageContents}/usr,$out}/share/icons/hicolor/512x512/apps/sunsama.png
    substituteInPlace $out/share/applications/sunsama.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=sunsama'
  '';

  meta = {
    description = "Digital daily planner that helps you feel calm and stay focused";
    homepage = "https://sunsama.com";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ dan-kc ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "sunsama";
  };
}
