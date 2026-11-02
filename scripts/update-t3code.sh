#!/usr/bin/env bash
#
# Pin T3 Code to its latest stable (non-nightly) GitHub release.
#
# Updates the nixpkgs-t3code flake input to pick up the newest build recipe,
# then rewrites modules/t3code.json with the release's version, source hash,
# and the pnpm and cargo dependency hashes (found by building each
# fixed-output derivation against a fake hash). Finishes with a full build so
# a broken session-TTL patch surfaces here, not during `make switch`.
#
# Usage: update-t3code.sh [--force]   # --force re-pins even if current
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN="$REPO_ROOT/modules/t3code.json"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

current=$(jq -r .version "$PIN")
# /releases/latest skips prereleases, which is where the nightlies live.
latest=$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest | jq -r .tag_name)
latest=${latest#v}
echo "Current: $current"
echo "Latest:  $latest"

if [ "$current" = "$latest" ] && [ "${1:-}" != "--force" ]; then
	echo "Already up to date."
	exit 0
fi

backup=$(mktemp)
cp "$PIN" "$backup"
trap 'cp "$backup" "$PIN"; echo "Failed; restored modules/t3code.json" >&2' ERR

set_pin() {
	jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$PIN" >"$PIN.tmp" && mv "$PIN.tmp" "$PIN"
}

# Builds <attr> of the t3code package as this checkout would.
build() {
	nix build --no-link --impure --expr "
		let
			flake = builtins.getFlake \"path:$REPO_ROOT\";
			pkgs = import flake.inputs.nixpkgs-t3code { system = builtins.currentSystem; };
		in (pkgs.callPackage $REPO_ROOT/modules/t3code.nix { })$1"
}

# Builds a fixed-output derivation against the fake hash (an expected failure)
# and prints the hash nix reports.
fod_hash() {
	{ build "$1" 2>&1 || true; } | sed -n 's/.*got: *\(sha256-[^ ]*\).*/\1/p' | tail -1
}

nix flake update nixpkgs-t3code --flake "$REPO_ROOT"

set_pin version "$latest"
set_pin srcHash "$(nix flake prefetch --json "github:pingdotgg/t3code/v$latest" | jq -r .hash)"
set_pin pnpmDepsHash "$FAKE_HASH"
set_pin cargoHash "$FAKE_HASH"

for key in pnpmDepsHash:.unwrapped.pnpmDeps cargoHash:.resourceMonitor.cargoDeps; do
	hash=$(fod_hash "${key#*:}")
	[ -n "$hash" ] || { echo "Could not determine ${key%%:*}" >&2; false; }
	set_pin "${key%%:*}" "$hash"
done

echo "Building t3code $latest..."
build ""

trap - ERR
rm "$backup"
echo ""
echo "Pinned t3code $current -> $latest"
echo "Next: make switch"
