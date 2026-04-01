# Shared DevOps / cloud / Kubernetes tooling
#
# These are "global" tools I want available everywhere
#
{ config, lib, pkgs, unstable, ... }:

{
  home.packages = [
    # GitHub CLI
    pkgs.gh

    # Containers
    pkgs.docker

    # Kubernetes CLI & utilities
    unstable.kubectl
    pkgs.k9s
    pkgs.kubectx

    # Cloud CLIs
    pkgs.azure-cli
    (pkgs.google-cloud-sdk.withExtraComponents (
      with pkgs.google-cloud-sdk.components;
      [
        gke-gcloud-auth-plugin
      ]
    ))
    pkgs.terraform

    # Networking
    pkgs.tailscale

  ];
}
