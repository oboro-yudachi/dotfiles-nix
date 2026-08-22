# Homebrew を宣言的に管理する。
#
# ★方針: cleanup = "zap"★
# 宣言に無い formula/cask/tap を容赦なく削除する（cask は設定ファイルまで消す）。
# そのぶん、このファイルの taps/brews/casks が実機の状態（`brew tap` /
# `brew list --installed-on-request` / `brew list --cask`）と一致していることが必須。
# 更新するときは必ず実機で上記コマンドを実行して裏取りしてから直すこと。
{
  inputs,
  username,
  ...
}:
{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  # 単機で /opt/homebrew が既に稼働している前提。Homebrew 本体は brew.sh から入れた
  # 既存のものを使い、nix-homebrew には所有権の管理だけ任せる。
  nix-homebrew = {
    enable = true;
    user = username;
    enableRosetta = false;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    user = username;

    onActivation = {
      cleanup = "zap";
      autoUpdate = false;
      upgrade = false;
    };

    # 手動 `brew bundle` 実行時にも Nix 生成の Brewfile を使わせる
    global.brewfile = true;

    taps = [
      "d12frosted/emacs-plus"
    ];

    brews = [
      # --- Emacs / Doom 本体とビルド依存（nixpkgs では代替しづらい） ---
      # macOS 向け独自パッチ（ネイティブフルスクリーン等）が含まれる特殊 tap のため nixpkgs に移行不可
      "d12frosted/emacs-plus/emacs-plus@30"
      # 依存関係には現れないが Doom Emacs の起動に必要
      "jpeg"
      # nixpkgs の libvterm は Linux 専用（meta.platforms に aarch64-darwin が含まれない）
      "libvterm"
      # markdown viewer系
      "markdown"
      # pdf-tools（epdfinfo）のビルドに必要。emacs-plus 自体が Homebrew 製なので
      # ビルドツールチェーンを Homebrew 側で揃える
      "poppler"

      # --- 低レベル依存（本来は自動で入るが on-request として実機に存在するので、
      #     明示しないと cleanup="zap" で削除される） ---
      "autoconf"
      "coreutils"
      "fontconfig"
      "gmp"
      "openssl@3"
      "readline"
      "zstd"

      # --- emacs-plus@30 の transitive dependency（2026-08-22 の事故を受けて明示化） ---
      # 本来は `brews` に載っている emacs-plus@30 の依存として `cleanup="zap"` から
      # 保護されるはずだが、flake.lock の Homebrew 本体メジャーアップデート
      # （brew-src 5.1.11 → 6.0.16）を挟んだ darwin-rebuild switch で、この依存関係の
      # 解決が壊れてこれら十数個の formula が丸ごと zap され、Emacs.app が
      # "Library not loaded" でクラッシュする事故が起きた。
      # `brew deps -n d12frosted/emacs-plus/emacs-plus@30` の出力を裏取りに、
      # zap で消えたものを明示的に固定しておく。詳細は docs/homebrew-zap-emacs-crash.md。
      "gcc"
      "gdk-pixbuf"
      "giflib"
      "graphite2"
      "harfbuzz"
      "fribidi"
      "icu4c@78"
      "isl"
      "json-c"
      "libdatrie"
      "libgccjit"
      "libmpc"
      "librsvg"
      "libthai"
      "mpfr"
      "pango"
      "tree-sitter@0.25"
      "webp"
      "zlib"

      # --- 汎用 CLI ツール（nixpkgs 未対応、または homebrew-core 版を使う方針のもの） ---
      # Oracle Cloud Infrastructure の公式 CLI
      "oci-cli"
    ];

    # ★初回だけ手動で --adopt / --force が必要★
    # 以下は現状すべて brew 管理外（直接ダウンロード等）で /Applications に入っている。
    # 素の `brew install --cask` は「既に .app がある」ことを理由に失敗するので、
    # switch する前に一度だけ取り込んでおくこと。
    #   - バージョンが一致するもの: --adopt でそのまま取り込める
    #   - バージョンがズレているもの: --adopt は「別物では」と拒否するので、
    #     --force で brew 配布版に置き換えてから管理下に入れる
    #     （設定は ~/Library 側に残るアプリがほとんどなので通常は消えない）
    #
    # 取り込み済みなら brew bundle は already-installed と認識する。
    casks = [
      "font-hack-nerd-font"
      "font-juliamono"
      "font-rambla"

      # --- 実機の /Applications を調査して cask 化できたもの ---
      "appcleaner"
      "aside"
      "brave-browser"
      "claude"
      "cmux" # Ghostty ベースのターミナル。homebrew-cask 本体に統合済みで tap 不要
      "discord"
      "eagle"
      "figma"
      "google-chrome"
      "hiddenbar" # .app 名は "Hidden Bar" だが cask token は "hiddenbar"
      "keycastr"
      "menubarx"
      "notion"
      "one-switch"
      "raycast" # "Raycast Beta.app"（bundle id が別系統の次世代版）は cask が無いので対象外
      "yoink"

      # --- 未対応（cask はあるが今の brew のバージョンだと cask 定義の
      #     パースに失敗する。`brew update` してから追加すること） ---
      # "obs"
      # "zoom"

      # --- cask が存在しないので対象外 ---
      # LINE.app / RunCat.app / RunCatNeo.app
      # Keynote.app / Numbers.app / Final Cut Pro.app / Compressor.app（Mac App Store）
      # CheatSheet.app（旧 cheatsheet cask。上流で開発終了・配布停止のため
      #   2025-11-09 に Homebrew 側でも無効化された。DL URL が 404 で二度と入らない）
      # Glaze.app（cask token: glaze-app）。cask が配布する dmg 自体の Info.plist が
      #   壊れていて CFBundleShortVersionString が "0.0.0" になっており、既存の
      #   /Applications/Glaze.app（0.8.0）と版が一致しないとして --adopt が失敗する
      #   （2026-08 時点で確認）。上流の dmg が直るまで対象外。
      # Minecraft.app / Spotify.app: アプリ自身のオートアップデーターで常時更新される
      #   タイプで、実機の方が brew の cask より新しかったり（minecraft: 実機2.2.2 vs
      #   cask 2.1.3）、バージョン体系自体が噛み合わない（spotify）。brew 管理下に
      #   置くとダウングレードや adopt 失敗が起きるので意図的に対象外のまま。
    ];
  };
}
