#!/usr/bin/env python3
"""Generate ~/.config/opencode/opencode.json from shared settings + local models.

The live opencode config is generated rather than checked in, because its
sources cannot live in one file:

  opencode.base.json      shared, hand-written settings (mcp, default_agent,
                          skills), tracked in this repo and identical on every
                          host.
  ~/.config/mcp/servers.json
                          MCP servers shared with every harness (see
                          home/shared/mcp.nix), translated to opencode's shape.
                          Tokens stay in ~/.secrets: headers point at them with
                          opencode's {file:...} substitution.
  the local model servers the installed model set, which is host-specific and
                          changes whenever you download or remove a model.

Two servers are read, each into its own provider block, and whichever answers
is written -- so one script serves every host without per-host settings:

  Unsloth Studio  http://127.0.0.1:8888, on the mac and baremetal. Needs
                  Settings > API > "Keyless API access" = full (loopback-only,
                  and the only keyless scope that may switch models) and "Model
                  auto-switch" on, so a request naming a downloaded model loads
                  it. Studio only runs while its desktop app is open, so when it
                  is down the previous run's model list is kept.
  Ollama          http://127.0.0.1:11434, if one is running.

Merging them here rather than layering them through opencode's own config chain
(global -> OPENCODE_CONFIG -> project) is deliberate: that chain needs
OPENCODE_CONFIG in the environment, which GUI-launched clients do not have --
see the comment in home/shared/opencode.nix. One merged file is what every
client, terminal or GUI, actually reads.

Runs on every home-manager activation. Rerun by hand after downloading or
removing a model:

    nx-opencode-models-sync            # write ~/.config/opencode/opencode.json
    nx-opencode-models-sync --print    # dump to stdout instead
    nx-opencode-models-sync --max-ctx-mlx 65536

A server that is unreachable is skipped, and with neither up the base settings
are still written without a provider block, so a host with no model server
running keeps working mcp and skills config. A missing or malformed base is a
hard error instead -- writing a config without it would silently drop those
settings.

Context is capped per engine, because the two allocate KV cache differently:

  ggml (gguf)      pre-allocates the whole window at load. A 27B at the
                   advertised 262144 reserves ~17 GB of KV cache before the
                   first token, which OOMed Ollama's Metal backend on the mac
                   until the context was pinned. Capped hard.

  MLX (safetensors) allocates lazily as the sequence grows, so the window is a
                   ceiling rather than a reservation. Measured on a 64 GB M5
                   Pro: qwen3.6 35b-a3b nvfp4 completed a real 227k-token
                   prompt with no OOM. Costs nothing to set high.

The MLX cap is the models' native 262144. It was 131072, to stay off the
throughput cliff at the top of the window (measured, qwen3.6 35b-a3b nvfp4:
87.8 tok/s generation and 1328 tok/s prefill on a short context, versus 26.5
and 635 at ~227k). That cliff turns out to be front-loaded -- the same model
prefills at ~680 tok/s at 113k depth, so 131072 was paying nearly all of the
slowdown while buying back only half the window. Compaction costs more than
the remaining margin: opencode uses limit.context to decide when to compact,
and dropping history mid-task is a worse failure than a slow turn. Pass
--max-ctx-mlx to trade back if a session spends more time in prefill than a
compaction would have cost.

KV cache is not what bounds this, for either MLX model here. Both are hybrid
attention (qwen3_5's full_attention_interval = 4), so only a quarter of the
layers hold a cache that grows with the sequence; the rest are linear
attention with constant-size state. From each model's shipped config.json, at
2 B/value f16 cache:

  qwen3.6 35b-a3b  10 of 40 full-attn layers x 2 KV heads x 256 head_dim
                   -> 20 KiB/token ->  5 GiB at 262144
  qwen3.8 27b      16 of 64 full-attn layers x 4 KV heads x 256 head_dim
                   -> 64 KiB/token -> 16 GiB at 262144

Measured peak process memory on the 64 GB M5 Pro stays ~31-37 GiB across
requests from 0 to 140k tokens of context, against 35 GB of resident weights
-- i.e. flat in context length, which is what the table above predicts.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_UNSLOTH_HOST = os.environ.get("UNSLOTH_HOST", "http://127.0.0.1:8888")
DEFAULT_OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434")
CONFIG_DIR = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "opencode",
)
DEFAULT_BASE = os.path.join(CONFIG_DIR, "opencode.base.json")
DEFAULT_OUT = os.path.join(CONFIG_DIR, "opencode.json")
DEFAULT_MCP = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "mcp",
    "servers.json",
)
DEFAULT_MAX_CTX_GGML = 32768
DEFAULT_MAX_CTX_MLX = 262144
DEFAULT_MAX_OUTPUT = 8192

SCHEMA_URL = "https://opencode.ai/config.json"
GENERATED_NOTE = (
    "GENERATED by nx-opencode-models-sync -- do not edit. Shared settings live "
    "in home/shared/opencode/opencode.base.json (symlinked to "
    "~/.config/opencode/opencode.base.json) and home/shared/mcp/servers.json "
    "(MCP servers for every harness); the provider blocks below are read "
    "from the local Unsloth Studio and Ollama servers. Rerun after editing the "
    "base or after downloading or removing a model."
)


def api(host: str, path: str, payload: dict | None = None) -> dict:
    url = f"{host.rstrip('/')}{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def capped(native_ctx: int | None, cap: int) -> int:
    return min(native_ctx, cap) if native_ctx else cap


def model_entry(
    name: str, ctx: int, max_output: int, *, tools: bool, reasoning: bool,
    attachment: bool, options: dict | None = None,
) -> dict:
    entry = {
        "name": name,
        "tools": tools,
        "reasoning": reasoning,
        "attachment": attachment,
    }
    if options:
        entry["options"] = options
    entry["limit"] = {"context": ctx, "output": max_output}
    return entry


#----- Unsloth Studio -----

def unsloth_provider(
    host: str, max_ctx_ggml: int, max_ctx_mlx: int, max_output: int
) -> dict | None:
    """Studio's provider block, or None if it has nothing to offer right now."""
    try:
        listed = api(host, "/v1/models").get("data") or []
        local = api(host, "/api/models/local").get("models") or []
    except urllib.error.URLError as exc:
        print(f"note: no Unsloth Studio at {host} ({exc}); skipped", file=sys.stderr)
        return None

    # /api/models/config's is_gguf / is_mlx read false even for GGUF repos;
    # the local scan's model_format is the field that is actually set.
    gguf = {m.get("id") for m in local if m.get("model_format") == "gguf"}

    models: dict[str, dict] = {}

    for entry in sorted(listed, key=lambda m: m.get("id", "")):
        model_id = entry.get("id")
        if not model_id:
            continue
        quoted = urllib.parse.quote(model_id, safe="")
        try:
            info = api(host, f"/api/models/config/{quoted}")
        except urllib.error.URLError as exc:
            print(f"warning: skipping {model_id}: {exc}", file=sys.stderr)
            continue

        if info.get("is_embedding") or info.get("is_audio") or info.get("is_decision"):
            continue  # not chat providers

        engine = "ggml" if model_id in gguf else "MLX"
        cap = max_ctx_mlx if engine == "MLX" else max_ctx_ggml
        ctx = capped(info.get("max_position_embeddings"), cap)
        label = entry.get("display_name") or model_id.split("/")[-1]
        quant = entry.get("quant")

        # Studio does not report tool or thinking support per model the way
        # ollama's /api/show does; every chat model served here has both.
        models[model_id] = model_entry(
            f"{label}{f' {quant}' if quant else ''} ({engine})",
            ctx,
            max_output,
            tools=True,
            reasoning=True,
            attachment=bool(info.get("is_vision")),
        )

    if not models:
        return None

    return {
        "name": "Unsloth Studio (local)",
        "npm": "@ai-sdk/openai-compatible",
        "options": {"baseURL": f"{host.rstrip('/')}/v1"},
        "models": models,
    }


#----- Ollama -----

def ollama_context_length(model_info: dict) -> int | None:
    """Pull `<arch>.context_length` without needing to know the architecture."""
    for key, value in model_info.items():
        if key.endswith(".context_length") and isinstance(value, int):
            return value
    return None


def ollama_engine(info: dict) -> str:
    """safetensors is how ollama ships the MLX-native quants; gguf runs ggml."""
    details = info.get("details") or {}
    return "MLX" if details.get("format") == "safetensors" else "ggml"


def ollama_describe(tag: str, info: dict, engine: str) -> str:
    details = info.get("details") or {}
    size = details.get("parameter_size") or "?"
    quant = details.get("quantization_level") or "?"
    return f"{tag} — {size} {quant} ({engine})"


def ollama_provider(
    host: str, max_ctx_ggml: int, max_ctx_mlx: int, max_output: int
) -> dict | None:
    """Ollama's provider block, or None if it has nothing to offer right now."""
    try:
        tags = api(host, "/api/tags").get("models") or []
    except urllib.error.URLError as exc:
        print(f"note: no ollama at {host} ({exc}); skipped", file=sys.stderr)
        return None

    models: dict[str, dict] = {}

    for entry in sorted(tags, key=lambda m: m.get("name", "")):
        tag = entry.get("name")
        if not tag:
            continue
        try:
            info = api(host, "/api/show", {"model": tag})
        except urllib.error.URLError as exc:
            print(f"warning: skipping {tag}: {exc}", file=sys.stderr)
            continue

        caps = info.get("capabilities") or []
        if "completion" not in caps:
            continue  # embedding-only models are not chat providers

        engine = ollama_engine(info)
        cap = max_ctx_mlx if engine == "MLX" else max_ctx_ggml
        ctx = capped(ollama_context_length(info.get("model_info") or {}), cap)

        models[tag] = model_entry(
            ollama_describe(tag, info, engine),
            ctx,
            max_output,
            tools="tools" in caps,
            reasoning="thinking" in caps,
            attachment="vision" in caps,
            options={"num_ctx": ctx},
        )

    if not models:
        return None

    return {
        "name": "Ollama (local)",
        "npm": "ollama-ai-provider-v2",
        "options": {"baseURL": f"{host.rstrip('/')}/api"},
        "models": models,
    }


#----- Config -----

def load_base(path: str) -> dict:
    """The shared settings. Absent or broken is fatal -- see module docstring."""
    try:
        with open(path) as handle:
            base = json.load(handle)
    except FileNotFoundError:
        raise SystemExit(f"error: base config not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: base config {path} is not valid JSON: {exc}")

    if not isinstance(base, dict):
        raise SystemExit(f"error: base config {path} is not a JSON object")
    return base


def load_mcp(path: str) -> dict:
    """servers.json as an opencode mcp block. Absent is fine -- not every host has it."""
    try:
        with open(path) as handle:
            servers = json.load(handle).get("mcpServers") or {}
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: {path} is not valid JSON: {exc}")

    mcp: dict[str, dict] = {}
    for name, server in servers.items():
        if "command" in server:
            entry = {
                "type": "local",
                "command": [server["command"], *server.get("args", [])],
            }
            if "env" in server:
                entry["environment"] = server["env"]
        else:
            entry = {"type": "remote", "url": server["url"]}
            if "authFile" in server:
                entry["headers"] = {"Authorization": f"{{file:{server['authFile']}}}"}
        mcp[name] = entry
    return {"mcp": mcp} if mcp else {}


def previous_provider(out: str, name: str) -> dict | None:
    """The provider block an earlier run wrote, or None if there is none."""
    try:
        with open(out) as handle:
            return (json.load(handle).get("provider") or {}).get(name)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def deep_merge(base: dict, overlay: dict) -> dict:
    """Recursive merge; overlay wins, so a `provider` key in the base survives."""
    merged = dict(base)
    for key, value in overlay.items():
        current = merged.get(key)
        if isinstance(current, dict) and isinstance(value, dict):
            merged[key] = deep_merge(current, value)
        else:
            merged[key] = value
    return merged


def build(base: dict, mcp: dict, providers: dict[str, dict]) -> dict:
    overlay = deep_merge(mcp, {"provider": providers} if providers else {})

    # $schema and the generated-file note go first so a reader hits the warning
    # before the settings; everything else keeps the base's own key order.
    config = {
        "$schema": base.get("$schema", SCHEMA_URL),
        "//": GENERATED_NOTE,
    }
    rest = {key: value for key, value in base.items() if key != "$schema"}
    config.update(deep_merge(rest, overlay))
    return config


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--unsloth-host", default=DEFAULT_UNSLOTH_HOST, help="Unsloth Studio base URL"
    )
    parser.add_argument("--ollama-host", default=DEFAULT_OLLAMA_HOST, help="ollama base URL")
    parser.add_argument("--base", default=DEFAULT_BASE, help="shared settings path")
    parser.add_argument("--out", default=DEFAULT_OUT, help="output path")
    parser.add_argument("--mcp", default=DEFAULT_MCP, help="shared MCP server list")
    parser.add_argument(
        "--max-ctx-ggml",
        type=int,
        default=DEFAULT_MAX_CTX_GGML,
        help="context cap for gguf models (ggml pre-allocates KV cache)",
    )
    parser.add_argument(
        "--max-ctx-mlx",
        type=int,
        default=DEFAULT_MAX_CTX_MLX,
        help="context cap for MLX models (lazy KV allocation)",
    )
    parser.add_argument("--max-output", type=int, default=DEFAULT_MAX_OUTPUT)
    parser.add_argument(
        "--print", dest="to_stdout", action="store_true", help="print instead of write"
    )
    args = parser.parse_args()

    limits = (args.max_ctx_ggml, args.max_ctx_mlx, args.max_output)
    found = {
        "unsloth": unsloth_provider(args.unsloth_host, *limits)
        or previous_provider(args.out, "unsloth"),
        "ollama": ollama_provider(args.ollama_host, *limits),
    }
    providers = {key: block for key, block in found.items() if block}

    config = build(load_base(args.base), load_mcp(args.mcp), providers)
    rendered = json.dumps(config, indent=2, ensure_ascii=False) + "\n"

    if args.to_stdout:
        sys.stdout.write(rendered)
        return 0

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as handle:
        handle.write(rendered)

    counts = ", ".join(
        f"{len(block['models'])} {key}" for key, block in providers.items()
    ) or "no providers"
    print(f"wrote {args.out} ({counts})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
