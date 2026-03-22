# Shared Alacritty terminal configuration
# Platform-specific overrides (package, font size, env vars, shell) should
# be set in the host's home-*.nix file.
{ config, lib, ... }:

{
  programs.alacritty = {
    enable = true;

    settings = {
      env.TERM = "xterm-256color";

      font = {
        size = lib.mkDefault 12.0;
        normal = {
          family = "Hack Nerd Font Mono";
          style = "Regular";
        };

        bold = {
          family = "Hack Nerd Font Mono";
          style = "Bold";
        };

        italic = {
          family = "Hack Nerd Font Mono";
          style = "Italic";
        };

        bold_italic = {
          family = "Hack Nerd Font Mono";
          style = "Bold Italic";
        };
      };

      cursor.style = "Block";
      window.dynamic_title = true;
      window.decorations = "Full";
      scrolling.history = 100000;

      keyboard.bindings = [
        { key = "Key0"; mods = "Control"; action = "ResetFontSize"; }
        { key = "Equals"; mods = "Control"; action = "IncreaseFontSize"; }
        { key = "Minus"; mods = "Control"; action = "DecreaseFontSize"; }
        { key = "F"; mods = "Shift|Alt"; action = "SearchBackward"; }
        { key = "V"; mods = "Alt"; action = "ToggleViMode"; }
        { key = "N"; mods = "Shift|Control"; action = "CreateNewWindow"; }
      ];

      colors = with config.colorScheme.palette; {
        draw_bold_text_with_bright_colors = true;
        cursor = {
          cursor = "0x${base06}";
          text = "0x${base00}";
        };
        vi_mode_cursor = {
          cursor = "0x${base07}";
          text = "0x${base00}";
        };
        hints = {
          start = {
            foreground = "0x${base00}";
            background = "0x${base0A}";
          };
          end = {
            foreground = "0x${base00}";
          };
        };
        selection = {
          text = "0x${base00}";
          background = "0x${base06}";
        };
        search.matches = {
          foreground = "0x${base00}";
        };
        footer_bar = {
          foreground = "0x${base00}";
        };
        search.focused_match = {
          foreground = "0x${base00}";
          background = "0x${base0B}";
        };
        primary = {
          background = "0x${base00}";
          foreground = "0x${base05}";
          dim_foreground = "0x${base05}";
          bright_foreground = "0x${base05}";
        };
        indexed_colors = [
          {
            index = 16;
            color = "0x${base09}";
          }
          {
            index = 17;
            color = "0x${base06}";
          }
        ];
        normal = {
          black = "0x${base03}";
          white = "0x${base06}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          yellow = "0x${base0A}";
        };
        bright = {
          black = "0x${base00}";
          white = "0x${base06}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          yellow = "0x${base09}";
        };
      };
    };
  };
}
