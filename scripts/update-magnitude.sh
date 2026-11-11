#!/usr/bin/env bash
#
# Pin Magnitude to its latest GitHub release.
#
# Rewrites version, revision (the .deb build number) and hash in
# modules/magnitude.nix from the release's amd64 .deb, using the sha256 GitHub
# publishes for the asset. Finishes with a build so a changed .deb layout
# (the installPhase's --replace-fail patches) surfaces here, not during
# `make switch`.
#
# Usage: update-magnitude.sh [--check | --force]
#   --check   show the pinned and latest releases, change nothing
#   --force   re-pin even if current
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NIX_FILE="$REPO_ROOT/modules/magnitude.nix"
GH_REPO="magnitudedev/magnitude"

field() { sed -n "s/^  $1 = \"\(.*\)\";/\1/p" "$NIX_FILE"; }

current=$(field version)
release=$(curl -fsSL "https://api.github.com/repos/$GH_REPO/releases/latest")
latest=$(jq -r '.tag_name | sub("^@magnitudedev/cli@"; "")' <<<"$release")
echo "Pinned: $current-$(field revision)"
echo "Latest: $latest"

case "${1:-}" in
--check)
	[ "$current" = "$latest" ] && echo "Up to date." || echo "Notes: https://github.com/$GH_REPO/releases"
	exit 0
	;;
"" | --force) ;;
*)
	echo "Unknown option: $1" >&2
	exit 1
	;;
esac

if [ "$current" = "$latest" ] && [ "${1:-}" != "--force" ]; then
	echo "Already up to date."
	exit 0
fi

asset=$(jq -c --arg v "$latest" '.assets[] | select(.name | test("^magnitude-desktop_\($v)-[0-9]+_amd64\\.deb$"))' <<<"$release")
[ -n "$asset" ] || {
	echo "No amd64 .deb in release $latest" >&2
	exit 1
}
name=$(jq -r .name <<<"$asset")
revision=$(sed -n 's/.*-\([0-9]*\)_amd64\.deb$/\1/p' <<<"$name")
digest=$(jq -r '.digest // empty' <<<"$asset")
if [ -n "$digest" ]; then
	hash=$(nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}")
else
	hash=$(nix store prefetch-file --json "$(jq -r .browser_download_url <<<"$asset")" | jq -r .hash)
fi
echo "Asset:  $name"
echo "Hash:   $hash"

backup=$(mktemp)
cp "$NIX_FILE" "$backup"
trap 'cp "$backup" "$NIX_FILE"; echo "Failed; restored modules/magnitude.nix" >&2' ERR

sed -i \
	-e "s|^  version = \".*\";|  version = \"$latest\";|" \
	-e "s|^  revision = \".*\";|  revision = \"$revision\";|" \
	-e "s|^    hash = \"sha256-.*\";|    hash = \"$hash\";|" \
	"$NIX_FILE"
[ "$(field version)" = "$latest" ] && [ "$(field revision)" = "$revision" ] && grep -qF "$hash" "$NIX_FILE"

echo "Building magnitude $latest..."
nix build --no-link --impure --expr "(import (builtins.getFlake \"path:$REPO_ROOT\").inputs.nixpkgs { system = \"x86_64-linux\"; }).callPackage $NIX_FILE { }"

trap - ERR
rm "$backup"
echo ""
echo "Pinned magnitude $current -> $latest-$revision"
echo "Next: make switch"
