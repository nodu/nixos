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

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      # We want home-manager to use the same set of nixpkgs as our system.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-colors.url = "github:misterio77/nix-colors";

    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

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

  outputs = { self, nixpkgs, nixpkgs-unstable, nixos-hardware, home-manager, ... }@inputs:
    let
      home-manager-modules = inputs.home-manager.nixosModules;

      # Helper to create a NixOS system configuration
      mkSystem = { system, config, homeConfig, hardwareModules ? [], extraModules ? [], extraSpecialArgs ? {} }:
        let
          unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
        in
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit unstable; } // extraSpecialArgs;
          modules = [
            { nixpkgs.hostPlatform = system; }
            config
          ] ++ hardwareModules ++ extraModules ++ [
            home-manager-modules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit unstable; } // extraSpecialArgs;
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
              nordvpn = (pkgs.callPackage
                ./modules/vpn.nix
                { });
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
    };
}
