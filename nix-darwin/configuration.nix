# nix-darwin のトップモジュール。
{
  self,
  username,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./home_manager.nix
    ./homebrew.nix
    ./defaults.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # symbola（下記フォント）は unfree ライセンスなので、これだけ個別に許可する。
  # allowUnfree = true は広すぎるので使わない。
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "symbola" ];

  # Emacs のフォールバックフォント。無いと特定文字の描画で Emacs がクラッシュ／低速化する
  # （doom doctor の警告）。macOS ではフォントは /Library/Fonts/Nix Fonts に置かれる。
  fonts.packages = [ pkgs.symbola ];

  # 後方非互換なデフォルト変更を条件分岐させるための値。未設定だと評価エラーになる。
  system.stateVersion = 6;

  # 2025-01-30 以降、activation は全て root で実行される。従来「darwin-rebuild を
  # 実行したユーザー」に適用されていたオプション（homebrew / system.defaults 等）は
  # ここで指定したユーザーに適用される。
  system.primaryUser = username;

  users.users.${username}.home = "/Users/${username}";

  # nix-darwin の set-environment は PATH を「上書き」する。既定値は /opt/homebrew/bin を
  # 含まないため、明示しないと brew 製コマンドが軒並み PATH から消える。
  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  # sudo を Touch ID で認証できるようにする。/etc/pam.d/sudo_local を管理するので、
  # macOS アップデートで上書きされても再 switch で復活する。
  security.pam.services.sudo_local.touchIdAuth = true;

  # Determinate Nix と管理を競合させない。
  # /etc/nix/nix.conf は Determinate が自動生成する「編集禁止」ファイルで、
  # nix-darwin にも管理させると衝突する。設定を足すなら /etc/nix/nix.custom.conf。
  nix.enable = false;

  # どの世代がどのコミットから作られたか darwin-rebuild --list-generations で辿れるようにする
  system.configurationRevision = self.rev or self.dirtyRev or null;

  programs.zsh.enable = true;
}
