#!/usr/bin/env bash
#
# Pin base's llama.cpp (Unsloth's fork, built for the 3090 + 1080) to its
# latest GitHub release.
# Only applies while home/base-gtx1080.nix is imported; otherwise Studio
# uses its own prebuilt.
#
# Rewrites home/unsloth-llama-cpp.json with the release's tag, commit, source
# hash, and the web UI's npm dependency hash (found by building that
# fixed-output derivation against a fake hash). Doesn't build llama.cpp
# itself: that's an hour of CUDA, left to `make switch`.
#
# Studio can't flag llama.cpp updates for a pinned LLAMA_SERVER_PATH, so use
# --check to see how far behind the pin is. Unsloth releases most days; bump
# when a model won't load (unknown model architecture) or Studio updates.
#
# Usage: update-unsloth-llama.sh [--check | --force | <tag>]
#   --check   show the pinned and latest releases, change nothing
#   --force   re-pin even if current
#   <tag>     pin this release instead of the latest
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIN="$REPO_ROOT/home/unsloth-llama-cpp.json"
GH_REPO="unslothai/llama.cpp"
ATTR="nixosConfigurations.base.config.home-manager.users.matt.unsloth.llamaCpp"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

build_number() { sed -n 's/^b\([0-9]*\)-.*/\1/p' <<<"$1"; }

current=$(jq -r .tag "$PIN")
releases=$(curl -fsSL "https://api.github.com/repos/$GH_REPO/releases?per_page=100" |
	jq -r '.[] | select((.prerelease | not) and (.tag_name | test("^b[0-9]+-mix-"))) | "\(.tag_name) \(.published_at[:10])"')
latest=$(head -1 <<<"$releases" | cut -d' ' -f1)
echo "Pinned: $current"
echo "Latest: $latest"

if [ "${1:-}" = "--check" ]; then
	current_build=$(build_number "$current")
	newer=$(while read -r tag date; do
		[ "$(build_number "$tag")" -gt "$current_build" ] && echo "  $tag  $date"
	done <<<"$releases" || true)
	if [ -z "$newer" ]; then
		echo "Up to date."
	else
		echo "$(wc -l <<<"$newer") newer release(s):"
		echo "$newer"
		echo "Notes: https://github.com/$GH_REPO/releases"
	fi
	exit 0
fi

target=$latest
case "${1:-}" in
"" | --force) ;;
-*)
	echo "Unknown option: $1" >&2
	exit 1
	;;
*) target=$1 ;;
esac

if [ "$current" = "$target" ] && [ "${1:-}" != "--force" ]; then
	echo "Already up to date."
	exit 0
fi

backup=$(mktemp)
cp "$PIN" "$backup"
trap 'cp "$backup" "$PIN"; echo "Failed; restored home/unsloth-llama-cpp.json" >&2' ERR

set_pin() {
	jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$PIN" >"$PIN.tmp" && mv "$PIN.tmp" "$PIN"
}

# path: rather than the git flake, so an unstaged pin file is still seen.
fod_hash() {
	{ nix build --no-link "path:$REPO_ROOT#$ATTR.$1" 2>&1 || true; } |
		sed -n 's/.*got: *\(sha256-[^ ]*\).*/\1/p' | tail -1
}

rev=$(curl -fsSL "https://api.github.com/repos/$GH_REPO/commits/$target" | jq -r .sha)
set_pin tag "$target"
set_pin rev "$rev"
set_pin srcHash "$(nix flake prefetch --json "github:$GH_REPO/$rev" | jq -r .hash)"
set_pin npmDepsHash "$FAKE_HASH"

hash=$(fod_hash npmDeps)
[ -n "$hash" ] || {
	echo "Could not determine npmDepsHash" >&2
	false
}
set_pin npmDepsHash "$hash"

trap - ERR
rm "$backup"
echo ""
echo "Pinned llama.cpp $current -> $target"
echo "Next: make switch (rebuilds llama.cpp for CUDA, about an hour)"
