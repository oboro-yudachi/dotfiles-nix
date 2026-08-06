# zsh とシェル系ツール一式。
{ pkgs, ... }:
{
  home.sessionVariables = {
    EDITOR = "emacsclient -t -a 'emacs'";
    VISUAL = "emacsclient -c -a 'emacs'";
    LANG = "ja_JP.UTF-8";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.emacs.d/bin"
  ];

  home.shellAliases = {
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    lt = "eza --tree --level=2";
    cat = "bat";
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza.enable = true;
  programs.bat.enable = true;

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$username$directory$git_branch$character";
      username = {
        show_always = true;
        format = "[$user]($style) ";
      };
      directory.truncate_to_repo = false;
      nodejs.disabled = true;
      git_status.disabled = true;
    };
  };

  programs.zsh.enable = true;

  # Ghostty のターミナル設定。
  xdg.configFile."ghostty/config".source = ./ghostty/config;
}
