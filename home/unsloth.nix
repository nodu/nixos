# Unsloth Studio (local LLMs). On baremetal its bundled llama.cpp (own ROCm)
# runs on the 780M; opencode reaches it through nx-opencode-models-sync (see
# home/shared/opencode.nix).
{ config, lib, unstable, ... }:

let
  cfg = config.unsloth;

  # Unsloth Studio's installer builds its venv with `uv venv --python 3.13`. With
  # no uv-managed CPython downloaded yet, uv falls back to the first python3 on
  # PATH: a nixpkgs build whose loader ignores the FHS sandbox's /usr/lib64. The
  # pip wheels then can't find libstdc++, PyTorch fails to import, and Studio
  # reports "GPUs are present but PyTorch cannot use them" (chat-only). That is
  # what happened on a fresh base; baremetal already had a managed CPython, so it
  # worked by luck. Make uv always use its own standalone CPython, which links
  # against the FHS loader like any other distro would.
  #
  # The llama.cpp installer also wants one prebuilt CUDA bundle covering every
  # visible GPU. A pre-Volta card (base's GTX 1080, sm_61) is only in the
  # "legacy" bundle, which lacks newer SMs, so with a mixed pair no bundle fits,
  # the source build is skipped (no cmake), and GGUF models won't load. So either
  # run our own llama-server (unsloth.llamaCpp), or hide pre-Volta cards from
  # Studio. Without nvidia-smi (baremetal) the mask does nothing.
  unslothDesktop = unstable.unsloth-desktop.override {
    buildFHSEnv = args: unstable.buildFHSEnv (args // {
      profile = args.profile + ''
        export UV_PYTHON_PREFERENCE=only-managed
      '' + (if cfg.llamaCpp != null then ''
        export LLAMA_SERVER_PATH=${lib.getExe' cfg.llamaCpp "llama-server"}
      '' else ''
        if [ -z "''${CUDA_VISIBLE_DEVICES+x}" ] && command -v nvidia-smi >/dev/null; then
          gpus=$(nvidia-smi --query-gpu=uuid,compute_cap --format=csv,noheader 2>/dev/null |
            while IFS=', ' read -r uuid cap; do
              [ "''${cap%%.*}" -ge 7 ] 2>/dev/null && printf '%s,' "$uuid"
            done)
          if [ -n "$gpus" ]; then
            export CUDA_VISIBLE_DEVICES="''${gpus%,}"
          fi
          unset gpus
        fi
      '');
    });
  };
in
{
  options.unsloth = {
    llamaCpp = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        llama.cpp whose llama-server Studio runs instead of its downloaded
        prebuilt (LLAMA_SERVER_PATH). Use it when no prebuilt covers every GPU.
      '';
    };
  };

  config.home.packages = [ unslothDesktop ];
}
