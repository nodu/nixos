#Order 1
{
  description = "NixOS systems and tools by mattn";
  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:nixos/nixpkgs/release-26.05";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Build recipe for T3 Code only, so scripts/update-t3code.sh can move it
    # without updating everything else on unstable.
    nixpkgs-t3code.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Pinned nixpkgs 25.05 for packages that need older versions (e.g. terraform 1.12.x)
    nixpkgs-2505.url = "github:nixos/nixpkgs/nixos-25.05";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # We want home-manager to use the same set of nixpkgs as our system.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS system management (nix-darwin)
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Homebrew management
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      inputs.brew-src.follows = "brew-src";
    };
    # Track Homebrew's main branch instead of nix-homebrew's pinned release, so
    # brew and homebrew-core move together on `nix flake update`
    brew-src = {
      url = "github:Homebrew/brew";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-opencode = {
      url = "github:anomalyco/homebrew-tap";
      flake = false;
    };

    # Fix Nix apps in macOS Spotlight/Dock
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    handy = {
      url = "github:cjpais/Handy";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      # handy consumes bun2nix.overlays.default, and bun2nix (flake-parts)
      # computes `self'`, which forces flake.formatter for every system it
      # declares -- including x86_64-darwin. nixpkgs-unstable is 26.11, which
      # dropped x86_64-darwin, so that throws while evaluating ANY config with
      # handy in home.packages (reached via fonts.fontconfig -> home.path).
      # Pin only the bun2nix tooling to stable; handy itself stays on unstable.
      # 26.05 is the last stable with x86_64-darwin (it prints a deprecation
      # warning on every eval), so this workaround stops working at 26.11.
      inputs.bun2nix.inputs.nixpkgs.follows = "nixpkgs";
    };

    defaults = {
      url = "github:nodu/defaults";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Deliberately NOT following nixpkgs-unstable. opencode's node_modules is a
    # fixed-output derivation whose hash (nix/hashes.json upstream) is computed
    # against the bun in opencode's own nixpkgs pin. Pointing it at our unstable
    # gives it a different bun (1.4.x vs 1.3.x), which lays out node_modules
    # differently and fails the FOD hash check. Let it use its own pin.
    opencode = {
      url = "github:anomalyco/opencode/dev";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-2505, nixos-hardware, home-manager, darwin, nix-homebrew, homebrew-core, homebrew-cask, homebrew-opencode, mac-app-util, ... }@inputs:
    let
      home-manager-modules = inputs.home-manager.nixosModules;

      # Helper to create a NixOS system configuration
      mkSystem = { system, config, homeConfig, hardwareModules ? [ ], extraModules ? [ ], extraSpecialArgs ? { } }:
        let
          unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
          pkgs-2505 = import nixpkgs-2505 { inherit system; config.allowUnfree = true; };
        in
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit unstable pkgs-2505; } // extraSpecialArgs;
          modules = [
            { nixpkgs.hostPlatform = system; }
            config
          ] ++ hardwareModules ++ extraModules ++ [
            home-manager-modules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Matches mkDarwin: move a pre-existing dotfile aside instead of
              # failing activation with "would be clobbered".
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit unstable pkgs-2505; } // extraSpecialArgs;
              home-manager.users.matt = import homeConfig { inherit inputs; };
            }
          ];
        };

      # Helper to create a macOS (nix-darwin) system configuration
      mkDarwin = { system, homeConfig, extraSpecialArgs ? { } }:
        let
          unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
          pkgs-2505 = import nixpkgs-2505 { inherit system; config.allowUnfree = true; };
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit unstable pkgs-2505; } // extraSpecialArgs;
          modules = [
            mac-app-util.darwinModules.default
            home-manager.darwinModules.home-manager
            {
              home-manager.sharedModules = [
                mac-app-util.homeManagerModules.default
              ];
            }
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                user = "matt";
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "anomalyco/homebrew-tap" = homebrew-opencode;
                };
                mutableTaps = false;
                autoMigrate = true;
                trust = {
                  taps = [ "anomalyco/tap" ];
                };
              };
            }
            ./hosts/mac/configuration.nix
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit unstable pkgs-2505; } // extraSpecialArgs;
              home-manager.users.matt = import homeConfig { inherit inputs; };
            }
          ];
        };

      # handy is x86_64-only
      handy = inputs.handy.packages."x86_64-linux".default;

      opencodePackages = system: inputs.opencode.packages.${system};

      overlays = [
        #(import ./overlays/sddm.nix)
      ];

      # Shared by the x86_64 workstations (baremetal, base); pairs with
      # modules/workstation.nix and home/workstation.nix
      workstation = {
        extraSpecialArgs = {
          inherit handy;
          opencode-packages = opencodePackages "x86_64-linux";
        };
        extraModules = [
          { nixpkgs.overlays = overlays; }
          {
            nixpkgs.config.packageOverrides = pkgs: {
              nordvpn = (pkgs.callPackage ./modules/vpn.nix { });
              sunsama = (pkgs.callPackage ./modules/sunsama.nix { });
              magnitude = (pkgs.callPackage ./modules/magnitude.nix { });
            };
          }
        ];
      };
    in
    {
      nixosConfigurations.baremetal = mkSystem {
        system = "x86_64-linux";
        config = ./hosts/baremetal/configuration.nix;
        homeConfig = ./home/home-baremetal.nix;
        hardwareModules = [
          nixos-hardware.nixosModules.framework-13-7040-amd
        ];
        inherit (workstation) extraSpecialArgs extraModules;
      };

      # Desktop workstation + server: i7-6700K, GTX 1080 display, RTX 3090 for CUDA and a Windows VM
      nixosConfigurations.base = mkSystem {
        system = "x86_64-linux";
        config = ./hosts/base/configuration.nix;
        homeConfig = ./home/home-base.nix;
        hardwareModules = [
          nixos-hardware.nixosModules.common-cpu-intel-cpu-only
          nixos-hardware.nixosModules.common-pc
          nixos-hardware.nixosModules.common-pc-ssd
        ];
        inherit (workstation) extraSpecialArgs extraModules;
      };

      nixosConfigurations.rpi3 = mkSystem {
        system = "aarch64-linux";
        config = ./hosts/rpi3/configuration.nix;
        homeConfig = ./home/home-rpi3.nix;
        hardwareModules = [
          nixos-hardware.nixosModules.raspberry-pi-3
        ];
        extraModules = [
          {
            nixpkgs.config.packageOverrides = pkgs: {
              nordvpn = (pkgs.callPackage
                ./modules/vpn.nix
                { });
            };
          }
        ];
      };

      nixosConfigurations.bau = mkSystem {
        system = "aarch64-linux";
        config = ./hosts/bau/configuration.nix;
        homeConfig = ./home/home-bau.nix;
        hardwareModules = [
          nixos-hardware.nixosModules.raspberry-pi-4
        ];
        extraSpecialArgs = {
          opencode-packages = opencodePackages "aarch64-linux";
        };
        extraModules = [
          {
            nixpkgs.config.packageOverrides = pkgs: {
              nordvpn = (pkgs.callPackage
                ./modules/vpn.nix
                { });
            };
          }
        ];
      };

      #----- macOS (nix-darwin) -----
      darwinConfigurations.mac = mkDarwin {
        system = "aarch64-darwin";
        homeConfig = ./home/home-mac.nix;
      };
    };
}
