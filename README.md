# dotfiles-nix

> **前提**: Apple Silicon Mac (aarch64-darwin)
> マシン名・ユーザー名はマシンごとに異なります。セットアップ前にリポジトリ内の該当箇所を実際の値に書き換えてコミットしてください（手順 3 参照）。

## 1. Xcode Command Line Tools のインストール

macOS にはデフォルトで C コンパイラが存在しないため、Nix のインストールおよびパッケージのビルドに必要な `clang` / `make` / `git` を事前に用意します。

```sh
xcode-select --install
```

## 2. Nix のインストール

[nix-installer](https://github.com/DeterminateSystems/nix-installer)（Determinate Systems 製）を使用します。インストールコマンドは公式リポジトリを参照してください。

インストール後、シェルを再起動するか以下を実行します。

```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

## 3. リポジトリのクローンとマシン情報の反映

```sh
git clone https://github.com/oboro-yudachi/dotfiles-nix.git ~/dotfiles-nix
cd ~/dotfiles-nix
```

マシン名とユーザー名を以下のコマンドで確認します。

```sh
scutil --get LocalHostName  # マシン名
whoami                      # ユーザー名
```

確認した値を以下のファイルに反映します。

| ファイル | 書き換え箇所 |
|---|---|
| `flake.nix` | `darwinConfigurations` のキー（マシン名） |
| `nix-darwin/configuration.nix` | `users.users` のキーとホームパス（ユーザー名） |
| `nix-darwin/homebrew.nix` | `nix-homebrew.user` / `homebrew.user`（ユーザー名） |
| `nix-darwin/home_manager.nix` | `home-manager.users` のキー（ユーザー名） |
| `home-manager/home.nix` | `home.username` / `home.homeDirectory`（ユーザー名） |

書き換え後、コミットしてリポジトリに反映します。

```sh
git add -A && git commit -m "update: マシン名・ユーザー名を反映"
```

## 4. nix-darwin の初回適用

`<machine-name>` には手順 3 で設定したマシン名を指定します。

```sh
nix run nix-darwin -- switch --flake .#<machine-name>
```

初回実行時は nix-darwin 自体のセットアップも行われます。完了後は `darwin-rebuild` コマンドが使用可能になります。

## 5. 以降の設定変更の適用

このコマンドは **設定ファイルの変更を適用する**ためのものです。`flake.lock` に固定されたバージョンのまま環境を更新します。パッケージ自体のバージョンは変わりません。

```sh
darwin-rebuild switch --flake ~/dotfiles-nix#<machine-name>
```

## 6. パッケージのバージョン更新

`nix flake update` は `flake.lock` を更新し、各入力（nixpkgs・home-manager・nix-darwin など）を最新バージョンに引き上げます。更新後は手順 5 のコマンドで環境に反映します。

```sh
# nixpkgs のみ更新
nix flake update nixpkgs

# home-manager のみ更新
nix flake update home-manager

# nix-darwin のみ更新
nix flake update nix-darwin

# すべての入力を一括更新
nix flake update
```

更新後は手順 5 のコマンドで環境に反映します。

```sh
# flake.nixがあるディレクトリで実行
sudo darwin-rebuild switch --flake .
```

## 7. 動作確認

```sh
# Nix で管理されているパッケージの確認
nix profile list

# Homebrew で管理されているパッケージの確認
brew list
```
