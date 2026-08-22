# git / gh / diff ツール周り。
{ pkgs, lib, ... }:
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

  # gh-stack は nixpkgs 未対応のため gh extension install で管理
  home.activation.installGhStackExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "$HOME/.local/share/gh/extensions/gh-stack" ]; then
      ${pkgs.gh}/bin/gh extension install github/gh-stack
    fi
  '';
}
