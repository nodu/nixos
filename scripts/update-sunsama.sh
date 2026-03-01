#!/usr/bin/env bash
#
# Update the pinned Sunsama version and hash in modules/sunsama.nix
# by querying the ToDesktop release feed.
#
# The AppImage filename embeds a build ID (e.g. 260114cp6zmcvo0) that
# changes with every release, so both the version and build ID must be
# updated together.
#
# ToDesktop publishes a YAML feed with the latest version, filename,
# and sha512 hash -- no download required to compute the hash.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUNSAMA_NIX="$REPO_ROOT/modules/sunsama.nix"
FEED_URL="https://download.todesktop.com/2003096gmmnl0g1/latest-linux.yml"

# Extract current version from sunsama.nix
current_version=$(grep 'version = "' "$SUNSAMA_NIX" | head -1 | sed 's/.*version = "\(.*\)".*/\1/')
echo "Current version: $current_version"

# Fetch the release feed
echo "Checking Sunsama release feed..."
feed=$(curl -sL "$FEED_URL")

if [ -z "$feed" ]; then
	echo "Error: could not fetch release feed from $FEED_URL"
	exit 1
fi

# Parse version, filename, and sha512 from the YAML
latest_version=$(echo "$feed" | grep '^version:' | sed 's/version: //')
latest_path=$(echo "$feed" | grep '^path:' | sed 's/path: //')
latest_sha512=$(echo "$feed" | grep '^sha512:' | sed 's/sha512: //')

if [ -z "$latest_version" ] || [ -z "$latest_path" ] || [ -z "$latest_sha512" ]; then
	echo "Error: could not parse feed. Got:"
	echo "$feed"
	exit 1
fi

echo "Latest version:  $latest_version"
echo "Latest file:     $latest_path"

if [ "$current_version" = "$latest_version" ]; then
	echo "Already up to date."
	exit 0
fi

echo "Updating $current_version -> $latest_version"

# Extract build ID from filename (e.g. "sunsama-3.2.6-build-260114cp6zmcvo0-x86_64.AppImage")
latest_build_id=$(echo "$latest_path" | sed 's/.*-build-\([a-z0-9]*\)-.*/\1/')
# Nix SRI hash: prepend "sha512-" to the base64 sha512 from the feed
nix_hash="sha512-${latest_sha512}"

echo "Build ID: $latest_build_id"
echo "Hash:     $nix_hash"

# Update version, buildId, and hash in sunsama.nix
sed -i "s/version = \"$current_version\"/version = \"$latest_version\"/" "$SUNSAMA_NIX"
sed -i "s/buildId = \"[a-z0-9]*\"/buildId = \"$latest_build_id\"/" "$SUNSAMA_NIX"
sed -i "s|hash = \"sha512-[^\"]*\"|hash = \"${nix_hash}\"|" "$SUNSAMA_NIX"

echo ""
echo "Updated modules/sunsama.nix:"
echo "  version: $current_version -> $latest_version"
echo "  buildId: $latest_build_id"
echo ""
echo "Next steps:"
echo "  make test    # verify the config evaluates"
echo "  make switch  # apply the update"
