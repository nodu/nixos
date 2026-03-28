# Shared git configuration: multi-identity, SSH URL rewriting, aliases
{ config, lib, pkgs, ... }:

{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
      syntax-theme = "base16";
      dark = true;
      minus-style = "normal \"#3b1219\"";
      minus-emph-style = "normal \"#6e2532\"";
      plus-style = "normal \"#132d1d\"";
      plus-emph-style = "normal \"#1f5e37\"";
    };
  };

  programs.git = {
    # located here: ~/.config/git/config
    enable = true;
    lfs.enable = true;
    signing = {
      key = "";
      signByDefault = false;
    };
    includes = [
      {
        contents = {
          user = {
            email = "matt@10four.ai";
            name = "Matt Nodurfth";
          };
        };
        condition = "gitdir:~/repos/raiz/";
      }
    ];
    settings = {
      user = {
        name = "Matt Nodurfth";
        email = "mnodurft@gmail.com";
      };
      alias = {
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
        root = "rev-parse --show-toplevel";
      };
      core = {
        editor = "nvim";
        askPass = ""; # needs to be empty to use terminal for ask pass
      };
      credential.helper = "store"; # want to make this more secure
      branch.autosetuprebase = "always";
      color.ui = true;
      github.user = "nodu";
      push.default = "tracking";
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
      # url = {
      #   "git@bitbucket.com:" = {
      #     insteadOf = "https://bitbucket.com/";
      #   };
      #   "git@github.com:" = {
      #     insteadOf = "https://github.com/";
      #   };
      # };
    };
  };
}
