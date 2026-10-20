# LazyVim のユーザー設定（~/.config/nvim）を管理する。
#
# Doom（emacs.nix）と同じく、ディレクトリごと out-of-store symlink にする。
# LazyVim は :LazyExtras や :Lazy sync のたびに lazyvim.json / lazy-lock.json を
# 書き換えるので、読み取り専用の /nix/store への symlink だと破綻する。
# 書き込みは repo 内の home-manager/nvim に落ち、そのまま git で追跡できる。
#
# プラグイン本体は ~/.local/share/nvim（lazy.nvim が実行時に clone）に入る。
# Nix では管理しない。neovim 本体と ripgrep / fd / tree-sitter は cli.nix 側。
#
# ★初回切り替え時の注意★
# 既存の ~/.config/nvim が実ディレクトリだと symlink 化に失敗するので、
# 事前に `mv ~/.config/nvim ~/.config/nvim.bak` 等で退避してから switch すること。
{ config, ... }:
{
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/nvim";
}
