# Claude Code backend for Open WebUI (system service, :8090). Open WebUI can't
# use a Claude subscription itself; its companion app Open WebUI Computer
# (`cptr`) runs the Claude Code CLI under the personal login and serves it on
# :8000/v1 as an OpenAI-compatible provider (Meshnet and wired LAN; firewall
# rules in hosts/baremetal/configuration.nix).
# https://docs.openwebui.com/ecosystem/computer/ai/coding-agents/
{ config, ... }:

let
  home = config.home.homeDirectory;
in
{
  systemd.user.services.cptr = {
    Unit = {
      Description = "Open WebUI Computer (cptr)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "/etc/profiles/per-user/matt/bin/uvx --from cptr[agents] --with claude-agent-sdk cptr run --host 0.0.0.0 --port 8000 --headless";
      Environment = [
        "CLAUDE_CONFIG_DIR=${home}/.claude-personal"
        "PATH=/run/wrappers/bin:${home}/.local/bin:${home}/.nix-profile/bin:/etc/profiles/per-user/matt/bin:/run/current-system/sw/bin"
      ];
      WorkingDirectory = home;
      KillMode = "mixed";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
