# macOS のシステム設定を宣言化する。
#
# 反映されるのは主に system.primaryUser のユーザー（configuration.nix で指定）。
# 一部は再ログイン／再起動まで効かないので、末尾で activateSettings -u を叩いて即時反映する。
{ ... }:
{
  system.defaults = {
    NSGlobalDomain = {
      # キー長押しでアクセント文字メニューを出さず、キーリピートを優先する（vim 等で重要）
      ApplePressAndHoldEnabled = false;

      # キーリピートを速める
      InitialKeyRepeat = 15; # リピート開始までの遅延
      KeyRepeat = 2; # リピート間隔

      # トラックパッドのトラッキング速度
      "com.apple.trackpad.scaling" = 2.5;

      # タップでクリック。trackpad.Clicking だけだと HID 側が拾わず
      # 「押し込まないとクリックできない」状態になるので、こちらも必須。
      "com.apple.mouse.tapBehavior" = 1;
    };

    dock = {
      autohide = true; # Dock を自動的に隠す
      tilesize = 57; # アイコンサイズ
      magnification = true; # カーソルを乗せたとき拡大
      orientation = "bottom";
    };

    finder = {
      FXPreferredViewStyle = "clmv"; # カラム表示
      FXDefaultSearchScope = "SCev"; # 検索は This Mac（全体）
    };

    trackpad = {
      Clicking = true; # タップでクリック
    };
  };

  # system.defaults の一部（Dock の autohide 等）は再ログインまで反映されない。
  # activateSettings -u で即時反映する。2025-01-30 以降 postUserActivation は削除され、
  # activation は全て root 実行なので postActivation を使う。
  system.activationScripts.postActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
