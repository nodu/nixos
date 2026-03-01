nx-metadata() {
	cd ~/repos/nixos/ || exit
	nix flake metadata
	cd - || exit
}

nx-update() {
	cd ~/repos/nixos/ || exit
	make switch
	cd - || exit
}

nx-update-flakes() {
	cd ~/repos/nixos/ || exit
	nix flake update
	cd - || exit
}

nx-update-input() {
	if [ -z "$1" ]; then
		echo "Command:"
		echo "nix flake update nixos-hardware"
		echo "nx-update-input nixos-hardware"
		echo ""
	else
		nix flake update "$1"
	fi
}

nx-search() {
	nix-search
}

nx-info-size() {
	if [ -z "$1" ]; then
		echo "Command:"
		echo "nix path-info --recursive --size --closure-size --human-readable nixpkgs#vlc "
	else
		nix path-info --recursive --size --closure-size --human-readable "$1"
	fi
}

nx-shell() {
	if [ -z "$1" ]; then
		echo "Command:"
		echo "nx-shell package_name,package_name2"
	else
		nix shell nixpkgs#{"$1",hello} "${@:2}"
	fi
}

nx-update-nordvpn() {
	"$HOME/repos/nixos/scripts/update-nordvpn.sh"
}

nx-shell-unfree() {
	if [ -z "$1" ]; then
		echo "Command:"
		echo
	else
		export NIXPKGS_ALLOW_UNFREE=1
		nix shell --impure nixpkgs#{"$1",hello} "${@:2}"
	fi
}
