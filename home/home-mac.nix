# macOS home-manager configuration
{ inputs, ... }:
{ config, lib, pkgs, unstable, ... }:

let
  # Helper to create a Gmail .app bundle via activation script (bypasses
  # mac-app-util trampolines so Raycast only indexes one copy per app).
  makeGmailActivation = { name, appName, profile }:
    let
      appDir = "$HOME/Applications/${appName}.app";
      plist = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleExecutable</key>
          <string>${name}</string>
          <key>CFBundleIdentifier</key>
          <string>com.custom.${name}</string>
          <key>CFBundleName</key>
          <string>${appName}</string>
          <key>CFBundleVersion</key>
          <string>1.0</string>
        </dict>
        </plist>
      '';
      script = ''
        #!/bin/bash
        open -na "Google Chrome" --args --app=https://mail.google.com --profile-directory='${profile}'
      '';
    in
    ''
      mkdir -p "${appDir}/Contents/MacOS"
      printf '%s\n' ${lib.escapeShellArg script} > "${appDir}/Contents/MacOS/${name}"
      chmod +x "${appDir}/Contents/MacOS/${name}"
      printf '%s\n' ${lib.escapeShellArg plist} > "${appDir}/Contents/Info.plist"
    '';
in
{
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.defaults.homeManagerModules.default
    (import ./shared/neovim.nix { inherit inputs; })
    ./shared/shell.nix
    ./shared/git.nix
    ./shared/cli.nix
    ./shared/devops.nix
    ./shared/gpg.nix
    ./shared/ssh.nix
    ./shared/tmux.nix
    ./shared/alacritty.nix
    ./darwin/darwin.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.catppuccin-mocha;

  home.stateVersion = "23.11";
  home.enableNixpkgsReleaseCheck = false;

  xdg.enable = true;

  #----- Programs -----
  programs.defaults = {
    enable = true;
    basic.enable = true; # unrar-free doesn't build on aarch64-darwin
    git.enable = true;
    network.enable = true; # iproute2/wireshark in defaults are Linux-only
  };

  # Marked broken Oct 20, 2022 check later to remove this
  # https://github.com/nix-community/home-manager/issues/3344
  manual.manpages.enable = false;

  #----- Alacritty (macOS-specific overrides; shared config in ./shared/alacritty.nix) -----
  programs.alacritty.settings = {
    font.size = 14;
    # Treat Option as Alt/Meta so escape sequences (word-jump, delete-word, etc.) work
    window.option_as_alt = "Both";
    # Fix for shell path when launching from desktop
    terminal.shell.program = "${pkgs.zsh}/bin/zsh";
  };

  #----- Gmail app shortcuts -----
  # Created directly in ~/Applications/ to avoid duplicate Raycast results
  # (mac-app-util trampolines + nix store copies).
  home.activation.gmailApps = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    (makeGmailActivation { name = "gmail"; appName = "Gmail"; profile = "Profile 2"; })
    + (makeGmailActivation { name = "gmail-work"; appName = "Gmail Work"; profile = "Profile 1"; })
  );

  #----- macOS-specific packages -----
  home.packages = [
    # pkgs.bun
    # pkgs.fnm
    # pkgs.yarn
    # pkgs.postgresql
    # pkgs.awscli2
    # pkgs.zulu11
    # pkgs.cargo
    # pkgs.nodejs_22

    # Dev tools
    pkgs.go
    pkgs.cmake
    pkgs.ffmpeg
    pkgs.uv
  ];
}
