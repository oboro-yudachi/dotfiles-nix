# git / gh / diff ツール周り。
{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "shoh13";
        email = "10_draft_willful@icloud.com";
      };
      init.defaultBranch = "main";
    };
    ignores = [ "**/.claude/settings.local.json" ];
  };

  # delta: git diff のビジュアライザ
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.gh = {
    enable = true;
    settings = {
      version = 1;
      git_protocol = "https";
      editor = "emacsclient -t -a emacs";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  programs.lazygit.enable = true;
}
