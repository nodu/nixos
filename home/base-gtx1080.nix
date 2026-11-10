# Unsloth Studio's llama.cpp for the GTX 1080 + RTX 3090s. Import from
# home-base.nix together with hosts/base/gtx1080.nix.
{ inputs }:
{ lib, pkgs, ... }:

{
  # No Unsloth prebuilt covers both the 3090 (sm_86) and the 1080 (sm_61), so
  # build llama.cpp for both to split models across their 24 + 8 GB. CUDA 12.x
  # is the last line that supports Pascal. Its own nixpkgs instance because
  # cudaCapabilities is a nixpkgs config option.
  #
  # Unsloth's fork, not upstream: its models (e.g. unsloth/flint-GGUF) use
  # architectures upstream doesn't know. Pinned in unsloth-llama-cpp.json;
  # scripts/update-unsloth-llama.sh checks for and bumps to the latest release.
  unsloth.llamaCpp = let
    pin = lib.importJSON ./unsloth-llama-cpp.json;
    buildNumber = lib.head (builtins.match "b([0-9]+)-.*" pin.tag);
    cuda = import inputs.nixpkgs-unstable {
      inherit (pkgs.stdenv.hostPlatform) system;
      config = {
        allowUnfree = true;
        cudaCapabilities = [ "6.1" "8.6" ];
      };
    };
  in (cuda.llama-cpp.override { cudaSupport = true; }).overrideAttrs (old: {
    pname = "llama-cpp-nccl";
    version = pin.tag;
    src = pkgs.fetchFromGitHub {
      owner = "unslothai";
      repo = "llama.cpp";
      inherit (pin) rev;
      hash = pin.srcHash;
    };
    # nixpkgs' patch is for its older upstream tag
    patches = [ ];
    # The fork's test-download-model needs the network, which the sandbox lacks
    doCheck = false;
    inherit (pin) npmDepsHash;
    # --split-mode tensor syncs the cards every layer. The built-in AllReduce
    # needs Volta+ on every card, so without NCCL the 1080 forces a slow
    # fallback. Measured on Qwen3.8-27B: prompt processing 347 -> 400-490 tok/s,
    # generation ~3% slower (46.5 -> 45.1). No P2P here; NCCL goes via SHM.
    buildInputs = old.buildInputs ++ [ cuda.cudaPackages.nccl ];
    cmakeFlags = map
      (f:
        if lib.hasPrefix "-DLLAMA_BUILD_NUMBER" f then "-DLLAMA_BUILD_NUMBER:STRING=${buildNumber}"
        else if lib.hasPrefix "-DLLAMA_BUILD_COMMIT" f then "-DLLAMA_BUILD_COMMIT:STRING=${builtins.substring 0 7 pin.rev}"
        else f)
      old.cmakeFlags;
    # Studio looks for these beside llama-server (its prebuilt layout); in lib/
    # it can't confirm the fitter sizes DFlash/DSpark drafts and over-reserves VRAM.
    postInstall = (old.postInstall or "") + ''
      for f in $out/lib/libllama-common.so* $out/lib/libllama-server-impl.so*; do
        if [ -e "$f" ]; then ln -s "$f" $out/bin/; fi
      done
    '';
  });
}
