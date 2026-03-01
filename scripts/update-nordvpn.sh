#!/usr/bin/env bash
#
# Update the pinned NordVPN version and hashes in modules/vpn.nix
# by querying the official NordVPN Debian repository.
#
# Downloads both amd64 and arm64 .deb packages and updates their
# respective hashes in the hashes attrset.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VPN_NIX="$REPO_ROOT/modules/vpn.nix"
REPO_URL="https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/"

# Extract current version from vpn.nix
current_version=$(grep 'version = "' "$VPN_NIX" | head -1 | sed 's/.*version = "\(.*\)".*/\1/')
echo "Current version: $current_version"

# Query the repo index for the latest version (use amd64 listing as reference)
echo "Checking NordVPN repository..."
latest_deb=$(curl -sL "$REPO_URL" |
	grep -oP 'nordvpn_[0-9]+\.[0-9]+\.[0-9]+_amd64\.deb' |
	sort -V |
	tail -1)

if [ -z "$latest_deb" ]; then
	echo "Error: could not find any .deb packages in the repository"
	exit 1
fi

latest_version=$(echo "$latest_deb" | sed 's/nordvpn_\(.*\)_amd64\.deb/\1/')
echo "Latest version:  $latest_version"

if [ "$current_version" = "$latest_version" ]; then
	echo "Already up to date."
	exit 0
fi

echo "Updating $current_version -> $latest_version"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Download and hash both architectures
for arch in amd64 arm64; do
	deb_file="nordvpn_${latest_version}_${arch}.deb"
	deb_url="${REPO_URL}${deb_file}"

	echo "Downloading ${arch}: ${deb_url} ..."
	curl -sL -o "$tmpdir/$deb_file" "$deb_url"

	hash=$(nix hash file --sri "$tmpdir/$deb_file")
	echo "  hash: $hash"

	# Update the arch-specific hash in vpn.nix
	sed -i "s|${arch} = \"sha256-[^\"]*\"|${arch} = \"${hash}\"|" "$VPN_NIX"
done

# Update version in vpn.nix
sed -i "s/version = \"$current_version\"/version = \"$latest_version\"/" "$VPN_NIX"

echo ""
echo "Updated modules/vpn.nix:"
echo "  version: $current_version -> $latest_version"
echo ""
echo "Next steps:"
echo "  make test    # verify the config evaluates"
echo "  make switch  # apply the update"
