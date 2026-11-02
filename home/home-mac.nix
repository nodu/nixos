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
    ./shared/ds.nix
    ./shared/gpg.nix
    ./shared/ssh.nix
    ./shared/tmux.nix
    ./shared/alacritty.nix
    ./shared/ghostty.nix
    ./shared/agent-sessions.nix
    ./shared/claude.nix
    ./shared/opencode.nix
    ./shared/mcp.nix
    ./shared/agents.nix
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

  #----- Ghostty (macOS-specific overrides; shared config in ./shared/ghostty.nix) -----
  # nixpkgs cannot compile ghostty from source on darwin; ghostty-bin is a
  # repackaging of the official signed .dmg, so we use it in place of the
  # Linux GTK `ghostty` package.
  programs.ghostty.package = pkgs.ghostty-bin;
  programs.ghostty.settings = {
    font-size = 14;
    # Treat Option as Alt/Meta so escape sequences (word-jump, delete-word, etc.) work
    macos-option-as-alt = true;
  };


  #----- Gmail app shortcuts -----
  # Created directly in ~/Applications/ to avoid duplicate Raycast results
  # (mac-app-util trampolines + nix store copies).
  home.activation.gmailApps = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    (makeGmailActivation { name = "gmail"; appName = "Gmail"; profile = "Profile 2"; })
    + (makeGmailActivation { name = "gmail-work"; appName = "Gmail Work"; profile = "Profile 1"; })
  );

  #----- Claude wrapper apps -----
  # Lightweight .app wrappers that launch Claude with separate data directories.
  # Both use --user-data-dir so the desktop instances are fully isolated.
  # Focuses the existing instance via a recorded pidfile if already running.
  #
  # The desktop split (--user-data-dir, Electron cookies) and the CLI split
  # (CLAUDE_CONFIG_DIR, Keychain) are independent mechanisms. These launchers
  # exec the Claude binary directly rather than going through `open`, so the
  # environment set here is inherited by Electron and by the Claude Code it
  # embeds — which is what lets the two splits line up.
  #
  # Only Personal exports CLAUDE_CONFIG_DIR. Work deliberately leaves it unset:
  # see home/shared/claude.nix for why naming its own default would still move
  # the Keychain entry and force a re-login.
  home.activation.claudeApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    # --- Claude Work ---
    CLAUDE_WORK="$HOME/Applications/Claude Work.app"
    rm -rf "$CLAUDE_WORK"
    mkdir -p "$CLAUDE_WORK/Contents/MacOS"

    cat > "$CLAUDE_WORK/Contents/Info.plist" << 'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleExecutable</key>
      <string>claude-work</string>
      <key>CFBundleIdentifier</key>
      <string>com.custom.claude-work</string>
      <key>CFBundleName</key>
      <string>Claude Work</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
    </dict>
    </plist>
    PLIST

    cat > "$CLAUDE_WORK/Contents/MacOS/claude-work" << 'SCRIPT'
    #!/bin/bash
    PIDFILE="$HOME/.local/state/claude-work.pid"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        PID=$(cat "$PIDFILE")
        osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PID) to true"
    else
        mkdir -p "$HOME/.local/state"
        /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir="$HOME/Library/Application Support/Claude-Work" &
        echo $! > "$PIDFILE"
    fi
    SCRIPT
    chmod +x "$CLAUDE_WORK/Contents/MacOS/claude-work"
    "$LSREGISTER" -f "$CLAUDE_WORK"

    # --- Claude Personal ---
    CLAUDE_PERSONAL="$HOME/Applications/Claude Personal.app"
    rm -rf "$CLAUDE_PERSONAL"
    mkdir -p "$CLAUDE_PERSONAL/Contents/MacOS"

    cat > "$CLAUDE_PERSONAL/Contents/Info.plist" << 'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleExecutable</key>
      <string>claude-personal</string>
      <key>CFBundleIdentifier</key>
      <string>com.custom.claude-personal</string>
      <key>CFBundleName</key>
      <string>Claude Personal</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
    </dict>
    </plist>
    PLIST

    cat > "$CLAUDE_PERSONAL/Contents/MacOS/claude-personal" << 'SCRIPT'
    #!/bin/bash
    PIDFILE="$HOME/.local/state/claude-personal.pid"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        PID=$(cat "$PIDFILE")
        osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PID) to true"
    else
        mkdir -p "$HOME/.local/state"
        # Routes this instance's embedded Claude Code to the personal profile.
        export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
        /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir="$HOME/Library/Application Support/Claude" &
        echo $! > "$PIDFILE"
    fi
    SCRIPT
    chmod +x "$CLAUDE_PERSONAL/Contents/MacOS/claude-personal"
    "$LSREGISTER" -f "$CLAUDE_PERSONAL"
  '';

  #----- scrcpy launcher app -----
  # Mirrors the Android phone over wireless debugging without a terminal.
  # Connects via mDNS first because the connect port changes whenever wireless
  # debugging restarts. Uses the Homebrew scrcpy/adb (hosts/mac brews) by full
  # path since GUI launches don't get the shell PATH. Pairing is a one-time
  # manual step (`adb pair`) and is not handled here.
  home.activation.scrcpyApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    SCRCPY_APP="$HOME/Applications/Scrcpy.app"
    rm -rf "$SCRCPY_APP"
    mkdir -p "$SCRCPY_APP/Contents/MacOS"

    cat > "$SCRCPY_APP/Contents/Info.plist" << 'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleExecutable</key>
      <string>scrcpy-launcher</string>
      <key>CFBundleIdentifier</key>
      <string>com.custom.scrcpy</string>
      <key>CFBundleName</key>
      <string>Scrcpy</string>
      <key>CFBundleVersion</key>
      <string>1.0</string>
    </dict>
    </plist>
    PLIST

    cat > "$SCRCPY_APP/Contents/MacOS/scrcpy-launcher" << 'SCRIPT'
    #!/bin/bash
    # scrcpy runs adb itself and finds it via $ADB or PATH, so both must be exported
    export ADB=/opt/homebrew/bin/adb
    export PATH="/opt/homebrew/bin:$PATH"
    SCRCPY=/opt/homebrew/bin/scrcpy
    LOG="$HOME/.local/state/scrcpy-app.log"
    mkdir -p "$HOME/.local/state"
    exec >"$LOG" 2>&1

    notify() {
        osascript -e "display notification \"$1\" with title \"Scrcpy\""
    }

    # Already mirroring: bring the window forward instead of opening a second one
    PID=$(pgrep -x scrcpy | head -1)
    if [ -n "$PID" ]; then
        osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $PID) to true"
        exit 0
    fi

    network_device() {
        "$ADB" devices | awk 'NR > 1 && $2 == "device" && ($1 ~ /:/ || $1 ~ /_adb-tls-connect/) { print $1; exit }'
    }

    "$ADB" start-server

    # mDNS discovery takes a few seconds after the adb server starts
    for _ in 1 2 3 4 5 6 7 8; do
        [ -n "$(network_device)" ] && break
        ADDR=$("$ADB" mdns services | awk '$2 == "_adb-tls-connect._tcp" { print $3; exit }')
        [ -n "$ADDR" ] && "$ADB" connect "$ADDR"
        sleep 1
    done

    if [ -z "$(network_device)" ]; then
        notify "Phone not found. Is Wireless debugging on and the phone on the same network?"
        exit 1
    fi

    # Tuned for typing latency over Wi-Fi on the Pixel 11 Pro Fold:
    # - repeat-previous-frame-after keeps the encoder fed at ~60fps; otherwise
    #   it holds a keystroke's frame until the next change (or a 100ms timer)
    # - uhid acts as a physical keyboard, so the on-screen keyboard (and its
    #   per-key redraws) stays hidden
    # - h264 at 1600 felt most usable; --max-fps=60 felt the same or better than
    #   uncapped and saves encoding work against the 120Hz panel
    "$SCRCPY" -e \
        --max-size=1600 \
        --max-fps=60 \
        --keyboard=uhid \
        --video-codec=h264 \
        --video-codec-options=repeat-previous-frame-after:long=16666,priority:int=0,latency:int=0 \
        || notify "scrcpy exited with an error, see ~/.local/state/scrcpy-app.log"
    SCRIPT
    chmod +x "$SCRCPY_APP/Contents/MacOS/scrcpy-launcher"
    "$LSREGISTER" -f "$SCRCPY_APP"
  '';

  #----- macOS-specific packages -----
  home.packages = [
    # pkgs.bun
    # pkgs.fnm
    # pkgs.yarn
    # pkgs.postgresql
    # pkgs.awscli2
    # pkgs.cargo
    # pkgs.nodejs_22

    # Dev tools
    pkgs.jre
    pkgs.go
    pkgs.cmake
    pkgs.ffmpeg
  ];
}
