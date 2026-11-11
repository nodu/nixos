#!/usr/bin/env bash
#
# Pin opencode to its latest GitHub release.
#
# Points the opencode flake input at the release tag, then writes
# modules/opencode.json with that version and the node_modules hash for each
# Linux system (found by building upstream's node_modules_updater, a
# fixed-output derivation with a fake hash). Upstream's own nix/hashes.json
# goes stale between releases, so the flake uses these hashes instead.
# Finishes with a build of opencode for this machine.
#
# A system this machine can't build (aarch64-linux on base) is dropped from
# the pin, and bau then fails to evaluate until the script runs with --force
# on a host that can build it (baremetal emulates aarch64-linux).
#
# Usage: update-opencode.sh [--check | --force | <version>]
#   --check     show the pinned and latest releases, change nothing
#   --force     re-pin even if current
#   <version>   pin this release (e.g. 2.2.7) instead of the latest
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLAKE="$REPO_ROOT/flake.nix"
LOCK="$REPO_ROOT/flake.lock"
PIN="$REPO_ROOT/modules/opencode.json"
GH_REPO="anomalyco/opencode"
SYSTEMS=(x86_64-linux aarch64-linux)

current=$(jq -r .version "$PIN")
# /releases/latest can point at an old major line, so take the highest
# stable vX.Y.Z tag instead.
latest=$(curl -fsSL "https://api.github.com/repos/$GH_REPO/releases?per_page=50" |
	jq -r '.[] | select(.prerelease | not) | .tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) | ltrimstr("v")' |
	sort -V | tail -1)
echo "Pinned: $current"
echo "Latest: $latest"

target=$latest
case "${1:-}" in
--check)
	[ "$current" = "$latest" ] && echo "Up to date." || echo "Notes: https://github.com/$GH_REPO/releases"
	exit 0
	;;
"" | --force) ;;
-*)
	echo "Unknown option: $1" >&2
	exit 1
	;;
*) target=${1#v} ;;
esac

if [ "$current" = "$target" ] && [ "${1:-}" != "--force" ]; then
	echo "Already up to date."
	exit 0
fi

can_build() {
	{ nix config show system && nix config show extra-platforms; } | tr ' ' '\n' | grep -qx "$1"
}

backup=$(mktemp -d)
cp "$FLAKE" "$LOCK" "$PIN" "$backup/"
trap 'cp "$backup/flake.nix" "$FLAKE"; cp "$backup/flake.lock" "$LOCK"; cp "$backup/opencode.json" "$PIN"; echo "Failed; restored flake.nix, flake.lock and modules/opencode.json" >&2' ERR

sed -i "s|\"github:$GH_REPO/[^\"]*\"|\"github:$GH_REPO/v$target\"|" "$FLAKE"
grep -q "github:$GH_REPO/v$target\"" "$FLAKE"
nix flake update opencode --flake "$REPO_ROOT"
rev=$(jq -r .nodes.opencode.locked.rev "$LOCK")

hashes='{}'
for system in "${SYSTEMS[@]}"; do
	if ! can_build "$system"; then
		if [ "$current" = "$target" ]; then
			hash=$(jq -r --arg s "$system" '.nodeModules[$s] // empty' "$PIN")
			[ -n "$hash" ] && hashes=$(jq --arg s "$system" --arg h "$hash" '.[$s] = $h' <<<"$hashes")
		fi
		echo "Skipping $system: this machine can't build it." >&2
		continue
	fi
	echo "Computing node_modules hash for $system..."
	# Expected to fail; nix reports the real hash.
	hash=$({ nix build --no-link "github:$GH_REPO/$rev#packages.$system.node_modules_updater" 2>&1 || true; } |
		sed -n 's/.*got: *\(sha256-[^ ]*\).*/\1/p' | tail -1)
	[ -n "$hash" ] || {
		echo "Could not determine the node_modules hash for $system" >&2
		false
	}
	echo "  $hash"
	hashes=$(jq --arg s "$system" --arg h "$hash" '.[$s] = $h' <<<"$hashes")
done

jq -n --arg v "$target" --argjson h "$hashes" '{version: $v, nodeModules: $h}' >"$PIN"

this_system=$(nix config show system)
echo "Building opencode $target for $this_system..."
nix build --no-link "path:$REPO_ROOT#packages.$this_system.opencode"

trap - ERR
rm -r "$backup"
echo ""
echo "Pinned opencode $current -> $target"
for system in "${SYSTEMS[@]}"; do
	jq -e --arg s "$system" '.nodeModules[$s]' "$PIN" >/dev/null ||
		echo "Warning: no $system hash; run scripts/update-opencode.sh --force on a host that can build it before deploying." >&2
done
echo "Next: make switch"
