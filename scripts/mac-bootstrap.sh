#!/usr/bin/env bash
# Bootstrap nix-darwin on a fresh macOS install.
#
# Usage:
#   On a brand new Mac, run:
#     xcode-select --install
#     curl -fsSL https://raw.githubusercontent.com/nodu/nixos/main/scripts/mac-bootstrap.sh | bash
#
#   Or if the repo is already cloned:
#     make mac/bootstrap
#
# What this script does:
#   1. Installs Xcode CLI tools if missing
#   2. Installs Nix if missing
#   3. Clones the repo to ~/repos/nixos if missing
#   4. Stages files for flake visibility
#   5. Renames /etc/ files that conflict with nix-darwin
#   6. Runs the initial nix-darwin switch

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_URL="https://github.com/nodu/nixos.git"
REPO_DIR="$HOME/repos/nixos"

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Must run as the regular user (sudo is called internally where needed)
if [[ "$(id -u)" -eq 0 ]]; then
	error "Don't run this script as root. It will prompt for sudo when needed."
	exit 1
fi

#----- Step 1: Xcode CLI tools -----
if ! xcode-select -p &>/dev/null; then
	info "Installing Xcode command line tools..."
	xcode-select --install
	echo "Press enter after Xcode CLI tools installation completes."
	read -r
fi
info "Xcode CLI tools: OK"

#----- Step 2: Install Nix -----
if ! command -v nix &>/dev/null; then
	info "Installing Nix..."
	sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
	# Source nix in current shell
	if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
		. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
	fi
fi
info "Nix: OK"

#----- Step 3: Clone repo -----
if [[ -d "$REPO_DIR/.git" ]]; then
	info "Repo already exists at $REPO_DIR"
else
	info "Cloning repo to $REPO_DIR..."
	mkdir -p "$(dirname "$REPO_DIR")"
	git clone "$REPO_URL" "$REPO_DIR"
fi

#----- Step 4: Stage files for flake visibility -----
info "Staging files for flake visibility..."
(cd "$REPO_DIR" && git add -A)

#----- Step 5: Rename conflicting /etc/ files -----
info "Checking for /etc/ files that conflict with nix-darwin..."

ETC_FILES=("/etc/nix/nix.conf" "/etc/bashrc" "/etc/zshrc")
renamed=0
for f in "${ETC_FILES[@]}"; do
	if [[ -f "$f" && ! -f "${f}.before-nix-darwin" ]]; then
		warn "Renaming $f -> ${f}.before-nix-darwin"
		sudo mv "$f" "${f}.before-nix-darwin"
		renamed=$((renamed + 1))
	fi
done
if [[ $renamed -eq 0 ]]; then
	info "No conflicting files (already renamed or absent)."
fi

#----- Step 6: Run nix-darwin switch -----
info "Running initial nix-darwin switch..."
info "This will take a while on first run (downloading & building packages)."
echo ""

# nix-darwin requires sudo for activation (see nix-darwin/nix-darwin#1457)
# Use --extra-experimental-features so this works on a fresh install without
# needing experimental-features in nix.conf first (nix-darwin will manage
# nix.conf going forward via the flake configuration).
sudo nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake "${REPO_DIR}#mac"

echo ""
info "Bootstrap complete!"
info ""
info "Next steps:"
info "  - Grant accessibility permissions for Karabiner-Elements and AeroSpace"
info "  - Run 'gh auth login' to authenticate with GitHub"
info "  - Copy SSH keys to ~/.ssh/ (or run 'make secrets/restore')"
info "  - For future changes, use: make mac/switch"
