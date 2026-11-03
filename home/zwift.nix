# Optional Docker-based Zwift launcher: https://github.com/netbrain/zwift
{ config, pkgs, ... }:

{
  # docker run -v zwift-$USER:/data --name zwift-copy-op busybox true
  # docker cp .zwift-credentials zwift-copy-op:/data
  # docker rm zwift-copy-op
  home.file."zwift.sh" = {
    source = pkgs.fetchurl {
      # Pin the revision matching this hash; upstream moved the script off this path.
      url = "https://raw.githubusercontent.com/netbrain/zwift/7e5b697ba3e6bd624a843485d0d5612be18278b2/zwift.sh";
      hash = "sha256-joipzHtLvy+l4H+NOLTSpVf8bzVGUF4JVDcyfQIt5II=";
    };
    target = ".local/bin/zwift";
    executable = true;
  };

  xdg.desktopEntries.zwift = {
    type = "Application";
    name = "Zwift";
    exec = "${config.home.homeDirectory}/.local/bin/zwift";
    categories = [ "Application" "Game" ];
  };
}
