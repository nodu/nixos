#Order 1
{
  description = "NixOS systems and tools by mattn";
  inputs = {
    # Pin our primary nixpkgs repository. This is the main nixpkgs repository
    # we'll use for our configurations. Be very careful changing this because
    # it'll impact your entire system.
    nixpkgs.url = "github:nixos/nixpkgs/release-25.11";

    # We use the unstable nixpkgs repo for some packages.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Pinned nixpkgs 25.05 for packages that need older versions (e.g. terraform 1.12.x)
    nixpkgs-2505.url = "github:nixos/nixpkgs/nixos-25.05";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      # We want home-manager to use the same set of nixpkgs as our system.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS system management (nix-darwin)
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Homebrew management
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
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

    # TODO: pinned to last commit before neovim renamed nvim.desktop -> org.neovim.nvim.desktop
    # which breaks the nixpkgs neovim wrapper (rm $out/share/applications/nvim.desktop fails).
    # Unpin once nixpkgs wrapper.nix is updated to handle the new desktop file name:
    #   neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay/80b1f16dba171a70c44c2ee6ec9529876152a7f5";

    handy = {
      url = "github:cjpais/Handy";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    defaults = {
      url = "github:nodu/defaults";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode = {
      url = "github:anomalyco/opencode/dev";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-2505, nixos-hardware, home-manager, darwin, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask, homebrew-opencode, mac-app-util, ... }@inputs:
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
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                  "anomalyco/homebrew-tap" = homebrew-opencode;
                };
                mutableTaps = false;
                autoMigrate = true;
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

      overlays = [
        #(import ./overlays/sddm.nix)
      ];
    in
    {
      nixosConfigurations.baremetal = mkSystem {
        system = "x86_64-linux";
        config = ./hosts/baremetal/configuration.nix;
        homeConfig = ./home/home-baremetal.nix;
        hardwareModules = [
          nixos-hardware.nixosModules.framework-13-7040-amd
        ];
        extraSpecialArgs = {
          inherit handy;
          opencode-packages = inputs.opencode.packages."x86_64-linux";
        };
        extraModules = [
          { nixpkgs.overlays = overlays; }
          {
            nixpkgs.config.packageOverrides = pkgs: {
              nordvpn = (pkgs.callPackage ./modules/vpn.nix { });
              sunsama = (pkgs.callPackage ./modules/sunsama.nix { });
            };
          }
        ];
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
          opencode-packages = inputs.opencode.packages."aarch64-linux";
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
