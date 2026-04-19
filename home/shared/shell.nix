# Shared shell configuration: zsh, bash, direnv, session variables, shell scripts
{ config, lib, pkgs, ... }:

{
  home.sessionVariables = {
    LANG = "en_US.UTF-8";
    LC_CTYPE = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
    MANROFFOPT = "-c";
  };

  home.sessionPath = [
    "$HOME/.npm/global/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
  ];

  xdg.configFile = {
    "nixos-functions.sh".text = builtins.readFile ../nixos-functions.sh;
    "apps.sh".text = builtins.readFile ../apps.sh;
    "aliases".text = builtins.readFile ../aliases;
    "m-os.sh".text = builtins.readFile ../m-os.sh;
    "shellConfig".text = builtins.readFile ../shellConfig;
    "fzf-m-os-preview-function.sh".source = config.lib.file.mkOutOfStoreSymlink ../fzf-m-os-preview-function.sh;
  };

  programs.bash = {
    enable = true;
    shellOptions = [ ];
    historyControl = [ "ignoredups" "ignorespace" ];
    initExtra = builtins.readFile ../bashrc;

    shellAliases = {
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gcp = "git cherry-pick";
      gdiff = "git diff";
      gl = "git prettylog";
      gp = "git push";
      gs = "git status";
      gt = "git tag";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # TODO: remove override once nixpkgs is updated past direnv fish test failure
    package = pkgs.direnv.overrideAttrs { doCheck = false; };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;

    shellAliases = { };

    history = {
      size = 1000000;
      save = 1000000;
      expireDuplicatesFirst = true;
      extended = true;
      share = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "z" "fzf" "kubectl" "kube-ps1" "web-search" ];
      theme = "robbyrussell";
    };

    #https://mynixos.com/home-manager/option/programs.zsh.initContent
    initContent = lib.mkMerge [
      (lib.mkOrder 500
        ''
          # Bind Alt+Arrow and Alt+Backspace escape sequences for word navigation/deletion.
          # Alacritty with option_as_alt sends xterm CSI sequences with modifier 3
          # (e.g. \e[1;3D for Alt+Left) which zsh does not bind by default.
          bindkey '\e[1;3D' backward-word        # Alt+Left Arrow
          bindkey '\e[1;3C' forward-word         # Alt+Right Arrow
          bindkey '\e\x7f'  backward-kill-word   # Alt+Backspace
        '')
      (lib.mkOrder 1000
        ''
          # Add hostname to prompt for distinguishing between hosts
          PROMPT="%{$fg[magenta]%}%m%{$reset_color%} $PROMPT"

          source $HOME/.config/nixos-functions.sh
          source $HOME/.config/apps.sh
          source $HOME/.config/aliases
          source $HOME/.config/m-os.sh
          source $HOME/.config/shellConfig
        '')
      (lib.mkOrder 1500
        ''
          # Run git status checks asynchronously -- results print below prompt when ready
          {
            check_git_status ~/repos
            check_git_status ~/.config #nvim
          } &
          disown
        '')
    ];
  };
}
