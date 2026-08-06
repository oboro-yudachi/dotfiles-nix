# home-manager のエントリポイント。
# 責務ごとのモジュールを imports に足していく。ここには最小限の定義だけ置く。
{ username, ... }:
{
  imports = [
    ./shell.nix
    ./git.nix
    ./cli.nix
    ./emacs.nix
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager 自身の後方互換の基準（25.11 = 初回セットアップ時の値）。
  # 据え置くこと。上げると設定の意味が変わる可能性がある（nixpkgs の更新とは無関係）。
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
