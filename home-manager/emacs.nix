# Doom Emacs のユーザー設定（~/.doom.d）を管理する。
#
# ★ディレクトリごと out-of-store symlink にする★
# Doom は config.org を保存するたび（literate モジュールの recompile フック）と
# doom sync のたびに config.org → config.el / packages.el / init.el を tangle する。
# つまり $DOOMDIR は「書き込み可能な実ディレクトリ」でなければならない。
# home.file の通常の source（読み取り専用な /nix/store への symlink）だと tangle 出力を
# 書き込めず破綻するため、mkOutOfStoreSymlink で ~/.doom.d を repo 内の実ディレクトリへ
# 向ける。tangle 出力はそのまま git 作業ツリー（home-manager/doom.d）に落ちる。
#
# 生成物（config.el / init.el / packages.el）も git 追跡する。config.org が唯一の
# 真実だが、Doom は config.org より先に init.el を読むため、init.el が無いと
# ブートストラップできない（鶏卵問題）。
#
# ★初回切り替え時の注意★
# 既存の ~/.doom.d が実ディレクトリのまま残っていると symlink 化に失敗するので、
# 事前に `mv ~/.doom.d ~/.doom.d.bak` 等で退避してから switch すること。
#
# emacs-plus@30 本体とそのビルド／連携チェーン（gcc / libgccjit / cmake / libvterm /
# poppler 等）は nix-darwin/homebrew.nix 側で管理する。
{ config, lib, pkgs, ... }:
{
  home.file.".doom.d".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/doom.d";

  # ★Dock / Spotlight から開くための Emacs.app★
  # emacs-plus は formula（cask ではない）なので Homebrew は .app を Cellar に
  # 置くだけで /Applications には出さない。ここで /Applications/Emacs.app を
  # emacs-plus@30 に固定する。/Applications は admin グループ書き込み可なので
  # sudo は不要（home-manager activation はユーザー権限で走る）。
  home.activation.linkEmacsApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ln -sfn /opt/homebrew/opt/emacs-plus@30/Emacs.app /Applications/Emacs.app
  '';

  # Doom Emacs org モジュール（+crypt +dragndrop +gnuplot +pandoc +roam）の外部依存
  home.packages = with pkgs; [
    gnupg
    gnuplot
    # org-roam のグラフ可視化（dot）
    graphviz
    pandoc
    # org-download-clipboard（クリップボード画像の貼り付け）
    pngpaste
  ];
}
