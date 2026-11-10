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
  profile = ''
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

  unslothDesktop = unstable.unsloth-desktop.override {
    buildFHSEnv = args: unstable.buildFHSEnv (args // {
      profile = args.profile + profile;
    });
  };

  # Same env, but running the Studio CLI the app installs under ~/.unsloth.
  # Studio updates in place: `unsloth studio update`, then restart the service.
  unslothCli = unstable.unsloth-desktop.override {
    buildFHSEnv = args: unstable.buildFHSEnv (args // {
      pname = "unsloth";
      profile = args.profile + profile;
      runScript = "${config.home.homeDirectory}/.unsloth/studio/unsloth_studio/bin/unsloth";
      extraInstallCommands = "";
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

    server = {
      enable = lib.mkEnableOption ''
        Studio as a boot-time model server on 0.0.0.0:8888 (user service
        unsloth-studio; its API key is printed to the journal). Replaces the
        desktop app's login autostart, since both want port 8888'';
      model = lib.mkOption {
        type = lib.types.str;
        description = "Model (HF repo) to load at start.";
      };
      ggufVariant = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GGUF quant variant, e.g. Q4_K_M.";
      };
    };
  };

  config = {
    home.packages = [ unslothDesktop unslothCli ];

    systemd.user.services.unsloth-studio = lib.mkIf cfg.server.enable {
      Unit = {
        Description = "Unsloth Studio model server";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        StartLimitIntervalSec = 600;
        StartLimitBurst = 3;
      };
      Service = {
        ExecStart = lib.concatStringsSep " " ([
          "${lib.getExe' unslothCli "unsloth"} studio run"
          "--model ${cfg.server.model}"
        ] ++ lib.optional (cfg.server.ggufVariant != null) "--gguf-variant ${cfg.server.ggufVariant}"
          ++ [ "--host 0.0.0.0 --port 8888" ]);
        ExecStop = "${lib.getExe' unslothCli "unsloth"} studio stop";
        WorkingDirectory = config.home.homeDirectory;
        Restart = "on-failure";
        RestartSec = 30;
        # The first start downloads the model.
        TimeoutStartSec = "infinity";
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Studio writes its own autostart entry pointing at the unwrapped binary,
    # which outside the FHS env can't find libwebkit2gtk and exits at login.
    # Replace it with the wrapped launcher.
    xdg.configFile."autostart/Unsloth.desktop" = {
      force = true;
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Unsloth
        Exec=${lib.getExe' unslothDesktop "unsloth-desktop"} --hidden
        StartupNotify=false
        Terminal=false
      '' + lib.optionalString cfg.server.enable ''
        Hidden=true
      '';
    };
  };
}
