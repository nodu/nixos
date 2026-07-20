# Shared Ghostty terminal configuration.
#
# On Linux the binary is the nixpkgs GTK `ghostty` (programs.ghostty.package
# default). nixpkgs cannot compile ghostty from source on darwin, so the macOS
# host overrides programs.ghostty.package = pkgs.ghostty-bin (a repackaging of
# the official signed .dmg). Either way home-manager manages the config, which
# ghostty reads from $XDG_CONFIG_HOME/ghostty/config on both platforms.
#
# Platform-specific overrides (package, font-size, macos-option-as-alt) live in
# the host's home-*.nix file.
{ lib, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "Catppuccin Mocha";

      font-family = "Hack Nerd Font Mono";
      font-size = lib.mkDefault 12;

      cursor-style = "block";
      window-inherit-working-directory = true;

      # Ctrl+1..9 => CSI-u sequences so tmux can bind C-1..C-9 for
      # Chrome-style window switching (legacy terminal encoding cannot
      # distinguish Ctrl+digit from the plain digit). Mirrors the Alacritty
      # bindings in ./alacritty.nix; tmux decodes these as C-1..C-9.
      keybind = [
        "ctrl+one=text:\\x1b[49;5u"
        "ctrl+two=text:\\x1b[50;5u"
        "ctrl+three=text:\\x1b[51;5u"
        "ctrl+four=text:\\x1b[52;5u"
        "ctrl+five=text:\\x1b[53;5u"
        "ctrl+six=text:\\x1b[54;5u"
        "ctrl+seven=text:\\x1b[55;5u"
        "ctrl+eight=text:\\x1b[56;5u"
        "ctrl+nine=text:\\x1b[57;5u"
      ];
    };
  };
}
