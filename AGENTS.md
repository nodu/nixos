# AGENTS.md

Instructions for AI coding agents working in this NixOS configuration repository.

## Repository Overview

Personal NixOS configuration using Nix flakes, home-manager, GNOME + i3 (X11 primary), and Sway (Wayland secondary). Three host types: `baremetal` (Framework 13 AMD, x86_64), `rpi3` (Raspberry Pi 3, aarch64 headless server), and `mac` (macOS via nix-darwin, aarch64-darwin).

## Build / Test / Apply Commands

```bash
make help             # Show all available targets (default)
make test             # Test configuration without switching (catches eval errors)
make switch           # Apply configuration changes (requires sudo)
make switch-logs      # Apply with detailed build logs
make list             # List system generations (for rollback)
make set-current gen=N # Switch to a specific generation
make clean            # Run garbage collection
make clean-generations # Delete generations older than 10 days
make clean-boot-partition # Clean up old boot entries
make optimise         # Optimize/deduplicate nix store
```

### NixOS Helper Functions (source home/nixos-functions.sh)

```bash
nx-update()                    # Update and switch system configuration
nx-update-flakes()            # Update all flake inputs
nx-update-input <input>       # Update specific flake input
nx-search <query>             # Search for packages
nx-info-size <package>        # Show package size information
nx-shell <packages>           # Create temporary shell with packages
```

### Raspberry Pi 3 Deployment

```bash
make rpi3/deploy         # Build on Framework (cross-compile via binfmt), push and activate on Pi
make rpi3/build          # Build rpi3 config locally (cross-compile)
make rpi3/copy           # Copy configuration files to Pi
make rpi3/switch         # Rebuild and switch (run directly on the Pi)
make rpi3/switch-remote  # Rebuild and switch via SSH
make rpi3/secrets        # Copy SSH keys to Pi
```

### VM/Remote Deployment

```bash
make vm/bootstrap0    # Bootstrap new VM from ISO
make vm/bootstrap     # Complete VM setup with configuration
make vm/copy         # Copy configuration to VM
make vm/switch       # Apply configuration on VM
```

### macOS (nix-darwin) Deployment

```bash
make mac/switch      # Apply darwin configuration (run on the Mac)
make mac/build       # Build darwin configuration
make mac/list        # List darwin generations
make mac/rollback    # Rollback to previous generation
make mac/clean       # Run garbage collection
```

The macOS config uses `darwinConfigurations.mac` in `flake.nix` via a `mkDarwin` helper (analogous to `mkSystem` for NixOS). It includes nix-homebrew for declarative Homebrew cask management and mac-app-util for Spotlight/Dock integration.

There is no unit test suite, linter, or CI pipeline. The primary validation method is `make test`, which evaluates the full NixOS configuration and reports any Nix evaluation errors. **Always run `make test` after making changes.**

## File Organization

| Path | Purpose |
|------|---------|
| `flake.nix` | Flake definition: inputs, outputs, nixpkgs/unstable channels, overlays |
| `hosts/baremetal/configuration.nix` | System-level config for Framework 13: boot, networking, services, system packages |
| `hosts/baremetal/hardware-configuration.nix` | Auto-generated hardware config (**do not edit**) |
| `hosts/rpi3/configuration.nix` | System-level config for Raspberry Pi 3 (headless, SSH-only) |
| `hosts/rpi3/hardware-configuration.nix` | Auto-generated hardware config (**do not edit**) |
| `hosts/mac/configuration.nix` | System-level config for macOS: nix settings, system.defaults, homebrew, fonts |
| `home/home-baremetal.nix` | User-level config for baremetal: GUI apps, dev tools, dotfiles |
| `home/home-rpi3.nix` | User-level config for rpi3: minimal, imports shared modules |
| `home/home-mac.nix` | User-level config for macOS: alacritty, dev tools, imports shared + darwin modules |
| `home/shared/` | Shared home-manager modules: `shell.nix`, `git.nix`, `cli.nix`, `gpg.nix`, `ssh.nix`, `neovim.nix` |
| `home/i3/`, `home/sway/` | Window manager configs (nix modules + external config files) |
| `home/darwin/` | macOS WM config: aerospace, sketchybar, karabiner (nix module + config files) |
| `modules/` | Custom NixOS modules (`vpns.nix`, `fhs-compat.nix`) and package derivations (`vpn.nix`) |
| `Makefile` | Build/deploy commands |

### Where to Add Things

- **System packages (baremetal)**: `hosts/baremetal/configuration.nix` in `environment.systemPackages`
- **System packages (rpi3)**: `hosts/rpi3/configuration.nix` in `environment.systemPackages`
- **User packages (baremetal)**: `home/home-baremetal.nix` in `home.packages`
- **User packages (mac)**: `home/home-mac.nix` in `home.packages`
- **Shared user config**: `home/shared/` modules (imported by all hosts)
- **NixOS services/modules**: `modules/` directory, imported in the host's `configuration.nix`
- **WM-specific packages/config**: `home/i3/i3.nix` or `home/sway/sway.nix`
- **macOS WM config**: `home/darwin/darwin.nix` (aerospace, sketchybar, karabiner)
- **macOS Homebrew casks**: `hosts/mac/configuration.nix` in `homebrew.casks`

## Agent Session IDs (claude / opencode)

So a pane restored after a crash (tmux resurrect keeps cwd but not the session
id) can be relaunched, both agent TUIs show the copy-pasteable resume command:

- **Claude Code**: bottom statusline appends `claude -r <session-uuid>` (`claude-personal -r` in the personal profile, plus the
  session name when set). Source: [`home/shared/claude/statusline.sh`](home/shared/claude/statusline.sh).
- **opencode**: a TUI slot plugin renders `opencode -s <session-id>` on the
  prompt row. Source: [`home/shared/opencode/plugins/session-id/index.tsx`](home/shared/opencode/plugins/session-id/index.tsx),
  declared in [`home/shared/opencode/tui.json`](home/shared/opencode/tui.json)
  (`plugin` array). TUI-only plugins go in `tui.json`, **not** `opencode.base.json` —
  the server plugin pass rejects a module that has no `server()` export.

`nx-save-sessions` (`home/scripts/agent-sessions.py`) remains the batch
save/restore path; the on-screen IDs complement it for single-pane recovery.

## opencode Config (local models)

`~/.config/opencode/opencode.json` is **generated** — do not edit it, and do not
add a home-manager `xdg.configFile` entry for that path. It is written by
`nx-opencode-models-sync` (`home/scripts/opencode-models.py`) from two
sources:

- [`home/shared/opencode/opencode.base.json`](home/shared/opencode/opencode.base.json) —
  shared, hand-written settings (`mcp`, `default_agent`, `agent`, `skills`),
  symlinked out-of-store to `~/.config/opencode/opencode.base.json`. **Edit this one.**
- the local model servers — host-specific, since the installed models and their
  safe context caps differ per host: Unsloth Studio on the Mac
  (`127.0.0.1:8888`, MLX), ollama on baremetal (`127.0.0.1:11434`, gguf). Each
  server that answers gets its own provider block.

The merge is done by the script rather than by opencode's own config layering
(`global -> OPENCODE_CONFIG -> project`), because that layering needs
`OPENCODE_CONFIG` in the environment and GUI-launched clients only import a
fixed allowlist of variables from a login shell — T3 Code drops it, so its
opencode server never saw the local models. See the comment in
[`home/shared/opencode.nix`](home/shared/opencode.nix).

The sync runs on every home-manager activation, so base edits and a `git pull`
propagate on rebuild. **Rerun it by hand after downloading or removing a model** —
a rebuild does not notice a changed model set. If no model server is reachable
the base settings are still written, minus the provider blocks.

## Desktop & Development Environment

- **Primary WM**: GNOME + i3 (X11)
- **Secondary WM**: Sway (Wayland)
- **Terminal**: Alacritty with Catppuccin Mocha theme
- **Shell**: Zsh with oh-my-zsh, extensive aliases in `home/nixos-functions.sh`
- **Editor**: Neovim nightly with external configuration
- **Languages**: Go, Python, Node.js with corresponding LSPs
- **Tools**: Modern CLI utilities (bat, fd, ripgrep, fzf, jq)
- **Git**: Configured for multiple identities, SSH key management via secrets
- **Docker**: Enabled for containerized development

## Power Management (baremetal)

**baremetal runs as an always-on server**, lid closed and on AC. Nothing may suspend it
automatically. The Framework 13 AMD uses s2idle (S0ix) rather than S3 deep sleep, so an
accidental suspend also drains the battery fast -- another reason the automatic triggers
are all off. Manual `systemctl suspend` and `systemctl hibernate` still work if the
laptop travels; only the automatic paths are disabled.

### Behavior

| Trigger | What happens |
|---|---|
| **Lid close, on AC** | Nothing -- `HandleLidSwitchExternalPower = "ignore"`. This is the one that matters; on AC it takes precedence over `HandleLidSwitch`. Note systemd ignores this setting entirely unless given an explicit value |
| **Lid close, on battery** | Suspends -- `HandleLidSwitch = "suspend"`. Set explicitly (it matches systemd's default) so all three lid cases read as deliberate. It only applies off AC, where suspending in a bag is what you want |
| **Lid close, docked or 2+ displays** | Nothing -- `HandleLidSwitchDocked = "ignore"`, which outranks both of the above |
| **Idle, any duration** | Nothing -- logind `IdleAction = "ignore"` |
| **Idle at the GDM greeter** | Nothing -- `services.displayManager.gdm.autoSuspend = false`. GDM runs its own idle timer that ignores logind, so this is required separately |
| **Idle 5 min (i3 session)** | Screen still locks via xss-lock/i3lock ([`home/i3/i3.config`](home/i3/i3.config)) -- lock and DPMS-off are kept, they don't suspend |
| **Power button, short press** | Suspends (`HandlePowerKey = "suspend"`). Deliberately kept: the button is the fingerprint reader on the keyboard deck, unreachable with the lid shut, so it can't be hit by accident in the always-on case -- and it's the behavior you want when the lid is open. If it *is* pressed, the host stays down until someone opens the lid |
| **Power button, ~5s hold** | Clean poweroff (`HandlePowerKeyLongPress`). systemd defaults this to `ignore`, which would leave only the firmware's unclean force-cut |
| **Kernel panic / oops** | Reboots after 30s (`boot.kernel.sysctl."kernel.panic"`) |
| **PID 1 wedged >60s** | Hardware watchdog resets the box (`systemd.settings.Manager.RuntimeWatchdogSec`, device `/dev/watchdog0`). 60s not 30s because heavy nix builds under swap pressure can delay PID 1, and a spurious reset mid-build is worse than slower recovery |
| **Reboot itself hangs >10min** | Watchdog forces the reset (`RebootWatchdogSec`) |
| **Boot and after resume** | Battery charge capped at 80% via `framework_tool --charge-limit` (systemd unit `framework-charge-limit`). The EC forgets this across a full power loss, hence re-applying |
| **Awake, battery 15% / 5% / 4%** | Warning / critical / danger notification via batsignal/dunst ([`home/i3/i3.nix`](home/i3/i3.nix)) |
| **Awake, battery 3%** | UPower hibernates. On AC the battery is effectively a UPS -- this is the graceful landing for a long power cut, not a normal path |

### Manual steps not expressible in Nix

- **Power On AC Attach** must be enabled in BIOS setup (F2 at boot). Without it the machine
  stays off after a power cut drains the battery, and Nix cannot set it.
- **Ethernet**: the Framework 13 has no built-in NIC. WiFi works (powersave is disabled in
  `networking.networkmanager.wifi.powersave`), but the ethernet expansion card is more
  reliable for a server.
- **Thermals**: lid closed, intake is the underside and exhaust is the hinge. Keep it on a
  hard surface with clearance. Check with `sensors` over SSH.

### Key files

- **System power config**: [`hosts/baremetal/configuration.nix`](hosts/baremetal/configuration.nix) -- logind (lid/power/idle actions), gdm autoSuspend, upower (critical battery action), charge limit unit, panic sysctls
- **Screen lock/DPMS**: [`home/i3/i3.config`](home/i3/i3.config) -- xset timeouts (use `exec` not `exec_always` so toggle state survives i3 reload)
- **Screensaver toggle**: [`home/i3/scripts/monitor/toggle-screensaver.sh`](home/i3/scripts/monitor/toggle-screensaver.sh) -- toggle DPMS/screensaver on/off (keep xset values in sync with i3.config)
- **Battery notifications**: [`home/i3/i3.nix`](home/i3/i3.nix) -- batsignal systemd user service, sends notifications via dunst
- **Swap/hibernation**: [`hosts/baremetal/hardware-configuration.nix`](hosts/baremetal/hardware-configuration.nix) -- 32GB swapfile, resume auto-detected by systemd initrd

### Remote access

SSH is key-only (`PasswordAuthentication = false`), matching bau. `matt` has lingering
enabled so systemd **user** units start at boot without an interactive login -- this is
what makes a reboot bring services back with the lid still shut.

**baremetal is reachable on the LAN only.** The `baremetal` SSH match block in
[`home/shared/ssh.nix`](home/shared/ssh.nix) resolves it over NordVPN Meshnet (nickname
`baremetal`, mesh IP `100.125.97.192` as `baremetal-mesh-ip`). Renaming the Meshnet
nickname breaks `ssh baremetal` until this file is updated and re-applied.

There are deliberately no `baremetal/*` Makefile targets. Rebuilds are done by SSHing in
(`ssh baremetal`) and running `make switch` there. The Mac is aarch64-darwin and cannot
build an x86_64-linux closure without a remote builder anyway, so a push-based deploy
target would have to build on baremetal regardless.

## Karabiner-Elements (macOS)

### Symlink Chain

`karabiner.json` is an **out-of-store symlink**. Edits to `home/darwin/config/karabiner.json` take effect immediately -- no `make mac/switch` needed. The chain is: `~/.config/karabiner/karabiner.json` -> nix store -> `home/darwin/config/karabiner.json`.

### Physical Key Modifier Swaps

The `simple_modifications` on the catch-all keyboard device swap modifiers:

| Physical key | After simple_modifications | Karabiner modifier name |
|---|---|---|
| **Cmd** (near spacebar) | left_option | `left_option` |
| **Option** (outer key) | left_command | `left_command` |
| **Caps Lock** | left_control | `left_control` |

When writing complex_modification rules, always use the **post-swap** modifier names in `from.modifiers.mandatory`. Rule descriptions should note the physical key for clarity, e.g. `"Option+N => ... (physical Cmd+N)"`.

### Alacritty Bundle IDs

Use both `^org\\.alacritty$` and `^io\\.alacritty$` in `frontmost_application_unless` exclusion lists. Current stable (0.16.x) uses `org.alacritty`; newer versions use `io.alacritty`. Do NOT add alacritty to arrow key exclusion lists -- Ctrl+arrow should pass through natively in Alacritty.

### shell_command vs key_code Rules

Rules using `shell_command` depend on the `karabiner_console_user_server` process. Rules using `key_code` remapping work via the core service and do not need it. If `shell_command` rules stop working but key remapping rules still work, check if the process is running:

```bash
launchctl list | grep console_user
```

A corrupted PID file at `~/.local/share/karabiner/pid/karabiner_console_user_server.pid` can prevent it from starting -- delete the file and launchd will restart it automatically (via `KeepAlive`).

### Editing karabiner.json

Use `python3 -c "import json; ..."` to parse, modify, and write the JSON programmatically (preserving structure, avoiding manual edit errors). Always validate after changes:

```bash
python3 -m json.tool home/darwin/config/karabiner.json > /dev/null
```

### Key Files

- [`home/darwin/config/karabiner.json`](home/darwin/config/karabiner.json) -- complex_modifications, simple_modifications, device configs
- [`home/darwin/darwin.nix`](home/darwin/darwin.nix) -- defines the out-of-store symlink
- [`home/shared/alacritty.nix`](home/shared/alacritty.nix) -- Alacritty keyboard bindings
- [`home/darwin/config/aerospace/aerospace.toml`](home/darwin/config/aerospace/aerospace.toml) -- AeroSpace tiling WM config (separate concerns from karabiner)

## Nix Code Style

### Formatting

- **2-space indentation**, no tabs
- No enforced line length limit (pragmatic)
- Formatter: `nixpkgs-fmt` (installed for editor use, no project config)
- Use `#` for all comments (never `/* */`)
- Section banners in large files: `#----- Section Name -----`
- TODO format: `# TODO: description`

### Module Function Signatures

```nix
# Standard NixOS module
{ config, pkgs, lib, ... }:
{ }

# Home-manager (curried to pass flake inputs)
{ inputs, ... }:
{ config, lib, pkgs, unstable, ... }:

# Package derivations (enumerate dependencies explicitly)
{ autoPatchelfHook, dpkg, fetchurl, lib, stdenv, ... }:
```

### Naming Conventions

- **Files**: lowercase kebab-case (`home-baremetal.nix`, `fhs-compat.nix`)
- **Local variables** in `let` blocks: camelCase (`nordVPNBase`, `handyFHS`)
- **Package names** (`pname`): lowercase with hyphens (`"nordvpn"`)
- **Module options**: standard NixOS dot paths (`services.nordvpn.enable`)

### Attribute Paths

Use **dotted paths** for single settings, **nested sets** for grouped settings:

```nix
boot.loader.systemd-boot.enable = true;       # Dotted for one-off
services.avahi = { enable = true; nssmdns4 = true; };  # Nested for groups
```

### Package References

- Prefer explicit `pkgs.` prefix: `pkgs.google-chrome`
- `unstable.` for unstable channel packages: `unstable.alacritty`
- `with pkgs; [ ... ]` acceptable for library lists (e.g., `fhs-compat.nix`)
- Do not mix `with pkgs;` and `pkgs.` prefix in the same list

### Imports and Dependencies

- Relative paths with `./` prefix: `imports = [ ./hardware-configuration.nix ];`
- Use `inherit` for concise binding: `inherit (pkgs) fetchFromGitHub;`
- External config files via `builtins.readFile`: `"i3/config".text = builtins.readFile ./i3.config;`

### Strings

- Single-line: double quotes (`"value"`)
- Multi-line scripts/config: `'' ... ''`
- Interpolation: `"${pkgs.foo}/bin/foo"` -- escape `$` inside `'' ''` with `''$`

### Conditionals and Options

- `lib.mkIf` for conditional config (not bare `if-then-else`)
- `lib.mkDefault` for overridable defaults
- `lib.mkForce` to override upstream values
- `lib.optionals` for conditional list elements
- `lib.mkOption` with `types.*` for custom module options

### Module Patterns

**Config-only module** (most files): directly set config attributes. **Full option module** (only `modules/vpns.nix`): defines `options` + uses `config = mkIf ...`.

### Let-In Usage

Top-level only. Used for intermediate derivations, pinned packages, and helper scripts:

```nix
let
  helperPkg = pkgs.writeShellApplication { ... };
in
{ home.packages = [ helperPkg ]; }
```

### Error Handling

- No `builtins.assert` or `throw` -- rely on NixOS type checking and eval errors
- `mdDoc` descriptions to document correct usage of custom options
- Shell scripts use `|| true` for non-fatal operations, `|| exit` for critical ones

## Stable vs Unstable Packages

- Default: `pkgs` (nixpkgs 26.05, stable)
- Unstable: `unstable` (nixpkgs-unstable), passed via `specialArgs`
- Use `unstable.` only when a newer version is specifically needed
- Version pinning: specific nixpkgs commit via `builtins.fetchTarball` with SHA256

## Secrets

- SSH keys and GPG keyrings managed outside Nix (`make secrets/backup`, `make secrets/restore`)
- Never commit `.ssh/`, `.gnupg/`, or `backup.tar.gz`

## Important Notes

- System uses experimental Nix features (flakes, nix-command)
- Home-manager manages user environment separately from system
- Framework 13 hardware optimizations are applied via nixos-hardware
- RPi3 uses binfmt cross-compilation from the x86_64 host for builds
- Auto garbage collection runs every 30 days, store optimization enabled
- The `NIXNAME` variable in the Makefile controls which host config is built (default: `baremetal`)

## Key Workflows

### Making Configuration Changes

1. Edit relevant `.nix` files
2. Test with `make test` to catch errors
3. Apply with `make switch`
4. Use `make list` to see generations for rollback if needed

### RPi3 Deployment

1. Edit `hosts/rpi3/configuration.nix` or `home/home-rpi3.nix`
2. Cross-compile and deploy: `make rpi3/deploy`
3. Or copy and rebuild on Pi: `make rpi3/copy && make rpi3/switch-remote`

### Managing System State

- Use `make clean-generations` periodically to free space
- Run `make optimise` to deduplicate store
- Check `make clean-boot-partition` if boot partition fills up

### Flake Updates

- Use `nx-update-flakes()` to update all inputs
- Use `nx-update-input <input>` for targeted updates
- Check nixpkgs versions in flake.nix - system uses 26.05, some packages from unstable

### Package Discovery

- Use `nx-search <query>` to find packages
- Use `nx-info-size <package>` to check size before installing
- Browse https://search.nixos.org for comprehensive package search
