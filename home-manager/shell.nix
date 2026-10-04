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
    # Doom core は XDG 準拠で ~/.config/emacs に置く方針（旧 ~/.emacs.d から移行）
    "$HOME/.config/emacs/bin"
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

  programs.zsh = {
    enable = true;
    # Lore 用の Notion PAT は macOS キーチェーン（service: notion-api-token）に置き、
    # 起動時に読み出して環境変数へ渡す。nix のファイルは Nix store に誰でも読める形で
    # 置かれるため、トークン本体はここに書かない。未登録なら何もしない。
    initContent = ''
      if _notion_token="$(security find-generic-password -a "$USER" -s notion-api-token -w 2>/dev/null)"; then
        export NOTION_API_TOKEN="$_notion_token"
      fi
      unset _notion_token
    '';
  };

  # Ghostty のターミナル設定。
  xdg.configFile."ghostty/config".source = ./ghostty/config;
}
