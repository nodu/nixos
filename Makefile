.DEFAULT_GOAL := help

help:
	@echo "NixOS Configuration Management"
	@echo ""
	@echo "Baremetal (Framework 13):"
	@echo "  make switch              - Apply configuration"
	@echo "  make switch-logs         - Apply with detailed build logs"
	@echo "  make test                - Test configuration without switching"
	@echo "  make list                - List system generations"
	@echo "  make clean               - Run garbage collection"
	@echo "  make clean-generations   - Delete generations older than 10 days"
	@echo "  make clean-boot-partition - Clean up old boot entries"
	@echo "  make optimise            - Deduplicate nix store"
	@echo "  make set-current gen=N   - Switch to generation N"
	@echo ""
	@echo "Raspberry Pi 3:"
	@echo "  make rpi3/deploy         - Build on Framework, push and activate on Pi"
	@echo "  make rpi3/copy           - Copy config to Pi"
	@echo "  make rpi3/switch         - Rebuild and switch (run on the Pi)"
	@echo "  make rpi3/switch-remote  - Rebuild and switch via SSH"
	@echo "  make rpi3/build          - Build rpi3 config (cross-compile)"
	@echo "  make rpi3/secrets        - Copy SSH keys to Pi"
	@echo ""
	@echo "Raspberry Pi 4 (bau):"
	@echo "  make bau/deploy          - Build on Framework, push and activate on bau"
	@echo "  make bau/copy            - Copy config to bau"
	@echo "  make bau/switch          - Rebuild and switch (run on bau)"
	@echo "  make bau/switch-remote   - Rebuild and switch via SSH"
	@echo "  make bau/build           - Build bau config (cross-compile)"
	@echo "  make bau/secrets         - Copy SSH keys to bau"
	@echo "  make bau/sd-image        - Build SD card image (cross-compile)"
	@echo "  make bau/partition       - Show post-dd partitioning instructions"
	@echo ""
	@echo "VM:"
	@echo "  make vm/bootstrap0       - Bootstrap new VM from ISO"
	@echo "  make vm/bootstrap        - Complete VM setup"
	@echo "  make vm/copy             - Copy config to VM"
	@echo "  make vm/switch           - Apply config on VM"
	@echo "  make vm/secrets          - Copy secrets to VM"
	@echo ""
	@echo "Updates:"
	@echo "  make update-nordvpn      - Update pinned NordVPN version"
	@echo ""
	@echo "macOS (nix-darwin):"
	@echo "  make mac/bootstrap       - First-time setup (run on a fresh Mac)"
	@echo "  make mac/switch          - Apply darwin configuration"
	@echo "  make mac/build           - Build darwin configuration"
	@echo "  make mac/list            - List darwin generations"
	@echo "  make mac/rollback        - Rollback to previous generation"
	@echo "  make mac/clean           - Run garbage collection"
	@echo "  make backup-karabiner    - Copy karabiner.json from live config"
	@echo ""
	@echo "Secrets:"
	@echo "  make secrets/backup      - Backup SSH keys and GPG keyring"
	@echo "  make secrets/restore     - Restore from backup"

# Connectivity info for Linux VM
#export NIXADDR=192.168.0.175
# NIXADDR ?= unset
NIXADDR ?= unset
NIXPORT ?= 22
NIXUSER ?= matt

# Raspberry Pi 3 connectivity
RPIADDR ?= rpi3

# Raspberry Pi 4 (bau) connectivity
BAUADDR ?= bau

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# The name of the nixosConfiguration in the flake
# MRNOTE not vm-intel, fully arm
NIXNAME ?= baremetal

# SSH options that are used. These aren't meant to be overridden but are
# reused a lot so we just store them up here.
SSH_OPTIONS=-o PubkeyAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no

switch:
	sudo NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake ".#${NIXNAME}"

switch-logs:
	sudo NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake ".#${NIXNAME}" --print-build-logs

test:
	sudo NIXPKGS_ALLOW_UNFREE=1 NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild test --flake ".#$(NIXNAME)"

list:
	sudo nix-env --list-generations -p /nix/var/nix/profiles/system

clean:
	sudo nix-collect-garbage

clean-generations:
	sudo nix-collect-garbage --delete-older-than 10d

optimise:
	nix-store --optimise

# https://www.reddit.com/r/NixOS/comments/10107km/how_to_delete_old_generations_on_nixos/
clean-boot-partition:
	sudo /run/current-system/bin/switch-to-configuration boot

set-current:
	sudo nix-env -p /nix/var/nix/profiles/system --switch-generation $(gen)

update-nordvpn:
	$(MAKEFILE_DIR)/scripts/update-nordvpn.sh

# bootstrap a brand new VM. The VM should have NixOS ISO on the CD drive
# and just set the password of the root user to "root". This will install
# NixOS. After installing NixOS, you must reboot and set the root password
# for the next step.
#
# NOTE(mitchellh): I'm sure there is a way to do this and bootstrap all
# in one step but when I tried to merge them I got errors. One day.
vm/bootstrap0:
	ssh $(SSH_OPTIONS) -p$(NIXPORT) root@$(NIXADDR) " \
		parted /dev/sda -- mklabel gpt; \
		parted /dev/sda -- mkpart primary 512MB -8GB; \
		parted /dev/sda -- mkpart primary linux-swap -8GB 100\%; \
		parted /dev/sda -- mkpart ESP fat32 1MB 512MB; \
		parted /dev/sda -- set 3 esp on; \
		sleep 1; \
		mkfs.ext4 -L nixos /dev/sda1; \
		mkswap -L swap /dev/sda2; \
		mkfs.fat -F 32 -n boot /dev/sda3; \
		sleep 1; \
		mount /dev/disk/by-label/nixos /mnt; \
		mkdir -p /mnt/boot; \
		mount /dev/disk/by-label/boot /mnt/boot; \
		nixos-generate-config --root /mnt; \
		sed --in-place '/system\.stateVersion = .*/a \
			nix.package = pkgs.nixVersions.latest;\n \
			nix.extraOptions = \"experimental-features = nix-command flakes\";\n \
  			services.openssh.enable = true;\n \
			services.openssh.settings.PasswordAuthentication = true;\n \
			services.openssh.settings.PermitRootLogin = \"yes\";\n \
			users.users.root.initialPassword = \"root\";\n \
		' /mnt/etc/nixos/configuration.nix; \
                nixos-install --no-root-passwd && reboot; \
	"
# after bootstrap0, run this to finalize. After this, do everything else
# in the VM unless secrets change.
vm/bootstrap:
	NIXUSER=root $(MAKE) vm/copy
	NIXUSER=root $(MAKE) vm/switch
	$(MAKE) vm/secrets
	ssh $(SSH_OPTIONS) -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		sudo reboot; \
	"

# copy our secrets into the VM
vm/secrets:
	# GPG keyring
	#rsync -av -e 'ssh $(SSH_OPTIONS)' \
	#	--exclude='.#*' \
	#	--exclude='S.*' \
	#	--exclude='*.conf' \
	#	$(HOME)/.gnupg/ $(NIXUSER)@$(NIXADDR):~/.gnupg
	# SSH keys
	# MRNOTE Added L as currently they're symlinks
	#rsync -avL -e 'ssh $(SSH_OPTIONS)' \
	rsync -av -e 'ssh $(SSH_OPTIONS) -p$(NIXPORT)' \
		--exclude='environment' \
		$(HOME)/.ssh/ $(NIXUSER)@$(NIXADDR):~/.ssh

# copy the Nix configurations into the VM.
vm/copy:
	rsync -av -e 'ssh $(SSH_OPTIONS) -p$(NIXPORT)' \
		--exclude='vendor/' \
		--exclude='.git/' \
		--rsync-path="sudo rsync" \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(NIXADDR):/nix-config

# have to run vm/copy before.
# run the nixos-rebuild switch command. This does NOT copy files so you
#if it complains about error upgrading system... use the --install-bootloader flag
#sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --install-bootloader --flake \"/nix-config#${NIXNAME}\" \

vm/switch:
	ssh $(SSH_OPTIONS) -p$(NIXPORT) $(NIXUSER)@$(NIXADDR) " \
		sudo NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nixos-rebuild switch --flake \"/nix-config#${NIXNAME}\" \
	"

#---------------------------------------------------------------------
# Raspberry Pi 3 targets
#---------------------------------------------------------------------

# Build rpi3 configuration (cross-compile via binfmt on x86_64 host)
rpi3/build:
	nix build ".#nixosConfigurations.rpi3.config.system.build.toplevel"

# Copy configuration to RPi3
# Note: git init + git add is required because Nix flakes only sees git-tracked
# files. Since we rsync without .git, we create a standalone repo on the Pi so
# flake evaluation works. --force ignores .gitignore rules that could hide files.
rpi3/copy:
	rsync -av -e 'ssh -p22' \
		--exclude='vendor/' \
		--exclude='.git' \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(RPIADDR):/home/matt/repos/nixos
	ssh -p22 $(NIXUSER)@$(RPIADDR) "cd /home/matt/repos/nixos && git init -q && git add --force ."

# Apply configuration on RPi3 remotely (requires passwordless sudo on rpi3)
rpi3/switch-remote:
	ssh -p22 $(NIXUSER)@$(RPIADDR) " \
		sudo nixos-rebuild switch --flake \"/home/matt/repos/nixos#rpi3\" \
	"

# Copy secrets to RPi3
rpi3/secrets:
	rsync -av -e 'ssh -p22' \
		--exclude='environment' \
		--exclude='known_hosts*' \
		--exclude='config' \
		$(HOME)/.ssh/ $(NIXUSER)@$(RPIADDR):~/.ssh

# Build SD card image for initial RPi3 install
# To re-enable, uncomment the sd-image-aarch64.nix import in hosts/rpi3/hardware-configuration.nix
# rpi3/sd-image:
# 	nix build ".#nixosConfigurations.rpi3.config.system.build.sdImage"

# Build rpi3 on x86_64 host (via binfmt), push closure, and activate on the Pi
rpi3/deploy:
	nix build ".#nixosConfigurations.rpi3.config.system.build.toplevel"
	nix copy --to ssh://$(NIXUSER)@$(RPIADDR) ./result
	# readlink runs locally to resolve the store path; this is intentional
	# because nix copy already pushed this exact path to the Pi
	ssh -t -p22 $(NIXUSER)@$(RPIADDR) " \
		sudo nix-env -p /nix/var/nix/profiles/system --set $$(readlink -f ./result) && \
		sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch \
	"

# Run directly on the Pi (from ~/repos/nixos) to rebuild and switch
rpi3/switch:
	sudo nixos-rebuild switch --flake "/home/matt/repos/nixos#rpi3"

#---------------------------------------------------------------------
# Raspberry Pi 4 (bau) targets
#---------------------------------------------------------------------

# Build bau configuration (cross-compile via binfmt on x86_64 host)
bau/build:
	nix build ".#nixosConfigurations.bau.config.system.build.toplevel"

# Copy configuration to bau
bau/copy:
	rsync -av -e 'ssh -p22' \
		--exclude='vendor/' \
		--exclude='.git' \
		$(MAKEFILE_DIR)/ $(NIXUSER)@$(BAUADDR):/home/matt/repos/nixos
	ssh -p22 $(NIXUSER)@$(BAUADDR) "cd /home/matt/repos/nixos && git init -q && git add --force ."

# Apply configuration on bau remotely (requires passwordless sudo)
bau/switch-remote:
	ssh -p22 $(NIXUSER)@$(BAUADDR) " \
		sudo nixos-rebuild switch --flake \"/home/matt/repos/nixos#bau\" \
	"

# Copy secrets to bau
bau/secrets:
	rsync -av -e 'ssh -p22' \
		--exclude='environment' \
		--exclude='known_hosts*' \
		--exclude='config' \
		$(HOME)/.ssh/ $(NIXUSER)@$(BAUADDR):~/.ssh

# Build bau on x86_64 host (via binfmt), push closure, and activate
bau/deploy:
	nix build ".#nixosConfigurations.bau.config.system.build.toplevel"
	nix copy --to ssh://$(NIXUSER)@$(BAUADDR) ./result
	ssh -t -p22 $(NIXUSER)@$(BAUADDR) " \
		sudo nix-env -p /nix/var/nix/profiles/system --set $$(readlink -f ./result) && \
		sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch \
	"

# Run directly on bau (from ~/repos/nixos) to rebuild and switch
bau/switch:
	sudo nixos-rebuild switch --flake "/home/matt/repos/nixos#bau"

# Build SD card image for bau (cross-compile via binfmt)
# After building, use bau/partition for next steps
bau/sd-image:
	nix build ".#nixosConfigurations.bau.config.system.build.sdImage"
	@echo ""
	@echo "Image built: $$(readlink -f ./result/sd-image/*.img*)"
	@echo "Next: run 'make bau/partition' for dd and partitioning instructions"

# Print post-dd partitioning instructions for the 1TB SD card
# These are destructive commands -- printed, not executed
bau/partition:
	@echo "=== Bau SD Card Setup (1TB) ==="
	@echo ""
	@echo "1. Find your SD card device:"
	@echo "   lsblk"
	@echo ""
	@echo "2. Write the image (replace /dev/sdX with your device):"
	@echo "   zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync"
	@echo ""
	@echo "3. Partition the card (the image creates p1=boot p2=root, both small):"
	@echo "   sudo parted /dev/sdX resizepart 2 250GB"
	@echo "   sudo resize2fs /dev/sdX2"
	@echo "   sudo parted /dev/sdX mkpart primary ext4 250GB 100%"
	@echo "   sudo mkfs.ext4 -L data /dev/sdX3"
	@echo ""
	@echo "4. Get UUIDs and update hosts/bau/hardware-configuration.nix:"
	@echo "   sudo blkid /dev/sdX1 /dev/sdX2 /dev/sdX3"
	@echo ""
	@echo "5. After updating UUIDs, re-comment the sd-image import in"
	@echo "   hosts/bau/hardware-configuration.nix, then boot the Pi."
	@echo ""
	@echo "6. Copy data from old Debian SD card:"
	@echo "   sudo mkdir -p /mnt/old /mnt/new-data"
	@echo "   sudo mount /dev/sdY1 /mnt/old          # old Debian root"
	@echo "   sudo mount /dev/sdX3 /mnt/new-data      # new data partition"
	@echo "   sudo rsync -av /mnt/old/path/to/data/ /mnt/new-data/"

#---------------------------------------------------------------------
# macOS (nix-darwin) targets
#---------------------------------------------------------------------

mac/bootstrap:
	$(MAKEFILE_DIR)/scripts/mac-bootstrap.sh

mac/switch:
	sudo darwin-rebuild switch --flake ".#mac"

mac/build:
	nix build ".#darwinConfigurations.mac.system"

mac/list:
	darwin-rebuild --list-generations

mac/rollback:
	sudo darwin-rebuild switch --rollback

mac/clean:
	nix-collect-garbage -d

backup-karabiner:
	cp ~/.config/karabiner/karabiner.json $(MAKEFILE_DIR)/home/darwin/config/karabiner.json

# Backup secrets so that we can transer them to new machines via
# sneakernet or other means.
.PHONY: secrets/backup
secrets/backup:
	tar -czvf $(MAKEFILE_DIR)/backup.tar.gz \
		-C $(HOME) \
		--exclude='.gnupg/.#*' \
		--exclude='.gnupg/S.*' \
		--exclude='.gnupg/*.conf' \
		--exclude='.ssh/environment' \
		.ssh/ \
		.gnupg \
		.secrets/

.PHONY: secrets/restore
secrets/restore:
	if [ ! -f $(MAKEFILE_DIR)/backup.tar.gz ]; then \
		echo "Error: backup.tar.gz not found in $(MAKEFILE_DIR)"; \
		exit 1; \
	fi
	echo "Restoring SSH keys and GPG keyring from backup..."
	mkdir -p $(HOME)/.ssh $(HOME)/.gnupg $(HOME)/.secrets
	tar -xzvf $(MAKEFILE_DIR)/backup.tar.gz -C $(HOME)
	chmod 700 $(HOME)/.ssh $(HOME)/.gnupg $(HOME)/.secrets
	chmod 600 $(HOME)/.ssh/* || true
	chmod 700 $(HOME)/.gnupg/* || true
	chmod 600 $(HOME)/.secrets/* || true
