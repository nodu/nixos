# Shared neovim configuration: neovim nightly + LSPs + linters/formatters
{ inputs, ... }:
{ config, lib, pkgs, unstable, ... }:

{
  programs.neovim = {
    # https://github.com/nix-community/neovim-nightly-overlay/issues/525
    enable = true;
    package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    plugins = [
    ];

    extraConfig = ''
      source ~/.config/nvim/bootstrap.init.lua
    '';

    extraPackages = [
    ];
  };

  # Clone or update LazyVim config from private repo
  # home.activation.neovimConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #   NVIM_DIR="$HOME/.config/nvim"
  #   if [ ! -d "$NVIM_DIR/.git" ]; then
  #     $DRY_RUN_CMD rm -rf "$NVIM_DIR"
  #     $DRY_RUN_CMD ${pkgs.git}/bin/git clone git@github.com:nodu/lazystuff.git "$NVIM_DIR" || true
  #   else
  #     $DRY_RUN_CMD ${pkgs.git}/bin/git -C "$NVIM_DIR" pull --ff-only || true
  #   fi
  # '';

  home.packages = [
    # neovim
    pkgs.tree-sitter

    # Minimal LSPs for Nix/shell config editing (shared across all hosts)
    pkgs.nil
    pkgs.nodePackages.bash-language-server
    pkgs.shellcheck
    pkgs.nixpkgs-fmt
    pkgs.shfmt
  ];
}
