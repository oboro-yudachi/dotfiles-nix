# Doom Emacs のユーザー設定（$DOOMDIR = ~/.config/doom）を管理する。
#
# ★ディレクトリごと out-of-store symlink にする★
# Doom は config.org を保存するたび（literate モジュールの recompile フック）と
# doom sync のたびに config.org → config.el / packages.el / init.el を tangle する。
# つまり $DOOMDIR は「書き込み可能な実ディレクトリ」でなければならない。
# home.file の通常の source（読み取り専用な /nix/store への symlink）だと tangle 出力を
# 書き込めず破綻するため、mkOutOfStoreSymlink で ~/.config/doom を repo 内の実ディレクトリへ
# 向ける。tangle 出力はそのまま git 作業ツリー（home-manager/doom.d）に落ちる。
#
# 生成物（config.el / init.el / packages.el）も git 追跡する。config.org が唯一の
# 真実だが、Doom は config.org より先に init.el を読むため、init.el が無いと
# ブートストラップできない（鶏卵問題）。
#
# ★XDG化（2026-08）★
# 以前は ~/.doom.d（レガシーパス）だったが、Doom core を ~/.config/emacs へ
# 再clone するタイミングで $DOOMDIR も XDG 準拠の ~/.config/doom に合わせた。
# 旧 ~/.doom.d は home-manager が管理していたので、次の switch で自動的に
# 消えるはず（orphan link cleanup）。念のため中身が空になったのを確認すること。
#
# ★初回切り替え時の注意★
# 既存の ~/.config/doom が実ディレクトリのまま残っていると symlink 化に失敗するので、
# 事前に `mv ~/.config/doom ~/.config/doom.bak` 等で退避してから switch すること。
#
# emacs-plus@30 本体とそのビルド／連携チェーン（gcc / libgccjit / cmake / libvterm /
# poppler 等）は nix-darwin/homebrew.nix 側で管理する。
{ config, lib, pkgs, ... }:
let
  # ネイティブtreesit用のグラマー（.dylib）をnixpkgsのビルド済みものから調達する。
  # emacs-plus本体はHomebrew管理のままでよい（Emacsのビルドに手を入れる必要はなく、
  # treesitが探す ~/.config/emacs/.local/cache/tree-sitter に .dylib を置くだけでよい）。
  # 言語を増やしたいときはここにgrammar名を足すだけ。elisp側の
  # treesit-language-source-alist / treesit-install-language-grammar は一切不要。
  treesitGrammars = pkgs.emacsPackages.treesit-grammars.with-grammars (g: with g; [
    tree-sitter-javascript
    tree-sitter-jsdoc
    tree-sitter-typescript
    tree-sitter-tsx
  ]);
in
{
  xdg.configFile."doom".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/doom.d";

  xdg.configFile."emacs/.local/cache/tree-sitter".source = "${treesitGrammars}/lib";

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
