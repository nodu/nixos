# Shared DevOps / cloud / Kubernetes tooling
#
# These are "global" tools I want available everywhere
#
{ config, lib, pkgs, unstable, pkgs-2505, ... }:

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
    pkgs.kubernetes-helm

    # Cloud CLIs
    pkgs.azure-cli
    (pkgs.google-cloud-sdk.withExtraComponents (
      with pkgs.google-cloud-sdk.components;
      [
        gke-gcloud-auth-plugin
      ]
    ))
    pkgs-2505.terraform  # pinned to 1.12.x

    # Networking
    pkgs.tailscale

    # Languages / runtimes
    pkgs.nodejs_22
    pkgs.python312
    pkgs.uv

    # Kubernetes dev workflow
    pkgs.kind
    pkgs.skaffold
    pkgs.dapr-cli

    # Build tools
    pkgs.gnumake
    pkgs.msgviewer

    # CLI aliases
    (pkgs.writeShellScriptBin "k"  ''exec kubectl "$@"'')
    (pkgs.writeShellScriptBin "kx" ''exec kubectx "$@"'')
    (pkgs.writeShellScriptBin "kn" ''exec kubens "$@"'')

    # Namespace/context shortcuts
    (pkgs.writeShellScriptBin "k-local" ''
      kubectl config use-context kind-tenfour-cluster && \
      kubectl config set-context --current --namespace=default
    '')
    (pkgs.writeShellScriptBin "k-dev" ''
      kubectl config use-context gke_tenfour-jbhunt-dev_us-central1_jbhunt-dev && \
      kubectl config set-context --current --namespace=jbhunt-dev
    '')
    (pkgs.writeShellScriptBin "k-prod" ''
      kubectl config use-context gke_tenfour-jbhunt-1_us-central1_jbhunt-prod && \
      kubectl config set-context --current --namespace=jbhunt-prod
    '')
    (pkgs.writeShellScriptBin "kns-dapr" ''
      kubectl config set-context --current --namespace=dapr-system
    '')

    # Tailscale exit node shortcuts
    (pkgs.writeShellScriptBin "ts-on"  ''sudo tailscale set --exit-node=tailscale-subnet-router'')
    (pkgs.writeShellScriptBin "ts-off" ''sudo tailscale set --exit-node='')

  ];
}
