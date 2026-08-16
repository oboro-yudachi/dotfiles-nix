# dotfiles

Mac（`shounoMacBook-Air` / macOS / arm64）の環境を宣言的に管理する。
flake 1つから `darwin-rebuild switch` するだけで、シェル・CLI・Homebrew・Emacs 設定が
再構築できる。

## 構成

```
flake.nix
nix-darwin/
  configuration.nix   # nix-darwin トップモジュール
  defaults.nix         # macOS のシステム設定（Dock/Finder/トラックパッド等）
  homebrew.nix         # Homebrew を宣言的に管理（cleanup="zap"）
  home_manager.nix      # home-manager を nix-darwin に配線
home-manager/
  home.nix       # エントリポイント
  shell.nix      # zsh とシェル系ツール
  git.nix        # git / gh / delta / lazygit
  cli.nix        # 汎用 CLI ツール・言語ランタイム
  emacs.nix      # ~/.config/doom（$DOOMDIR）と Doom の外部依存
  doom.d/        # Doom Emacs の設定（config.org が本体、init.el/packages.el を tangle）
docs/
  emacs-startup.md      # Emacs 起動が遅い件の調査ログ
  emacs-boot-bench.sh   # 上記の再現用ベンチスクリプト
```

## 日常の操作

### 設定を適用する

```sh
sudo darwin-rebuild switch --flake ~/dotfiles
```

- ホスト名 `shounoMacBook-Air` が `darwinConfigurations` のキーなので `#host` は省略できる。
- sudo は Touch ID で認証できる。

### 適用前に確認する（任意）

```sh
# ビルドだけして評価エラーが無いか見る
nix build ~/dotfiles#darwinConfigurations.shounoMacBook-Air.system

# フォーマット
nix fmt
```

### 更新する

```sh
cd ~/dotfiles
nix flake update              # 全 input を更新
nix flake update nixpkgs      # 個別に更新
sudo darwin-rebuild switch --flake .
```

### ロールバック

```sh
sudo darwin-rebuild --list-generations   # sudo 必須
sudo darwin-rebuild --rollback           # 直前の世代へ
```

世代管理では戻らないもの（`homebrew.onActivation.cleanup = "zap"` による削除・
macOS defaults・退避した dotfile）がある点に注意。

### 掃除（古い世代と store の GC）

```sh
sudo darwin-rebuild --list-generations
nix profile wipe-history --older-than 30d   # 世代を刈る
nix store gc                                 # store を回収する
```

「世代を消す → store を回収する」の2段階が必須（世代が参照している間は GC されない）。

### 動作確認

```sh
# Nix で管理されているパッケージの確認
nix profile list

# Homebrew で管理されているパッケージの確認（宣言と実体が一致しているはず）
brew list
brew list --cask
```

## 新規セットアップ（別マシンへの展開時）

このリポジトリはユーザー名・ホスト名を `flake.nix` の `username` / `hostname` に
集約してある。別マシンで使う場合は書き換えてからコミットすること。

1. Xcode Command Line Tools

   ```sh
   xcode-select --install
   ```

2. [nix-installer](https://github.com/DeterminateSystems/nix-installer)（Determinate Systems 製）で Nix をインストール

3. リポジトリをクローンし、`flake.nix` の `username` / `hostname` を実際の値に書き換える

   ```sh
   scutil --get LocalHostName  # マシン名
   whoami                      # ユーザー名
   ```

4. 初回適用

   ```sh
   nix run nix-darwin -- switch --flake ~/dotfiles
   ```

   完了後は `darwin-rebuild` コマンドが使えるようになる。以降は「日常の操作」を参照。

## Homebrew の管理方針について

`nix-darwin/homebrew.nix` は `cleanup = "zap"` — 宣言に無い formula/cask/tap を
容赦なく削除する設定にしてある。実機の `brew tap` / `brew list --installed-on-request` /
`brew list --cask` と乖離すると意図しない削除が起きるので、パッケージを手で
`brew install` したときは必ずこのファイルにも追記すること。
