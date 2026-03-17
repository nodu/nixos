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
make backup-karabiner # Copy live karabiner.json into repo
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

The Framework 13 AMD uses **s2idle** (S0ix) for suspend -- not S3 deep sleep. s2idle drains more power than S3, so suspend-then-hibernate is configured to prevent battery death during suspend. Hibernation resume is auto-detected via the systemd initrd.

### Behavior

| Trigger | What happens |
|---|---|
| **Idle 5 min** | Screen locks via xss-lock/i3lock ([`home/i3/i3.config:61`](home/i3/i3.config)) |
| **Idle 5.5 min** | Display off via DPMS ([`home/i3/i3.config:60`](home/i3/i3.config)) |
| **Idle 10 min** | Suspend-then-hibernate via logind IdleAction ([`hosts/baremetal/configuration.nix:39-42`](hosts/baremetal/configuration.nix)) |
| **Lid close** | Immediate suspend-then-hibernate ([`hosts/baremetal/configuration.nix:38`](hosts/baremetal/configuration.nix)) |
| **Power button** | Immediate suspend-then-hibernate ([`hosts/baremetal/configuration.nix:37`](hosts/baremetal/configuration.nix)) |
| **During suspend, every 1 min** | systemd wakes to check battery drain, hibernates early if needed ([`hosts/baremetal/configuration.nix:47-50`](hosts/baremetal/configuration.nix)) |
| **During suspend, after 2h** | Hibernate regardless ([`hosts/baremetal/configuration.nix:48`](hosts/baremetal/configuration.nix)) |
| **Awake, battery 15%** | Warning notification via batsignal/dunst ([`home/i3/i3.nix`](home/i3/i3.nix)) |
| **Awake, battery 5%** | Critical notification via batsignal/dunst ([`home/i3/i3.nix`](home/i3/i3.nix)) |
| **Awake, battery 4%** | Danger notification via batsignal/dunst ([`home/i3/i3.nix`](home/i3/i3.nix)) |
| **Awake, battery 3%** | UPower triggers hibernate ([`hosts/baremetal/configuration.nix:43-44`](hosts/baremetal/configuration.nix)) |

### Key files

- **System power config**: [`hosts/baremetal/configuration.nix`](hosts/baremetal/configuration.nix) -- logind (lid/power/idle actions), upower (critical battery action), systemd sleep (hibernate delay, suspend estimation)
- **Screen lock/DPMS**: [`home/i3/i3.config`](home/i3/i3.config) -- xset timeouts (use `exec` not `exec_always` so toggle state survives i3 reload)
- **Screensaver toggle**: [`home/i3/scripts/monitor/toggle-screensaver.sh`](home/i3/scripts/monitor/toggle-screensaver.sh) -- toggle DPMS/screensaver on/off (keep xset values in sync with i3.config)
- **Battery notifications**: [`home/i3/i3.nix`](home/i3/i3.nix) -- batsignal systemd user service, sends notifications via dunst
- **Swap/hibernation**: [`hosts/baremetal/hardware-configuration.nix`](hosts/baremetal/hardware-configuration.nix) -- 32GB swapfile, resume auto-detected by systemd initrd

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

- Default: `pkgs` (nixpkgs 25.11, stable)
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
- Check nixpkgs versions in flake.nix - system uses 25.11, some packages from unstable

### Package Discovery

- Use `nx-search <query>` to find packages
- Use `nx-info-size <package>` to check size before installing
- Browse https://search.nixos.org for comprehensive package search
