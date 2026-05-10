# dotfiles-nix

macOS (Apple Silicon) の環境を Nix で宣言的に管理するための dotfiles です。

## 設計思想

### 宣言的・再現可能な環境管理

環境構成をコードとして記述し、いつでも同一の状態を再現できることを目指しています。手作業によるセットアップを排除し、新しいマシンでも同じ開発環境を短時間で構築できます。

### ツールの役割分担

| ツール | 役割 |
|---|---|
| **nix-darwin** | macOS システム設定の宣言的管理（パス、PAM、シェルなど） |
| **home-manager** | ユーザー環境の管理（パッケージ、dotfiles、セッション変数） |
| **nix-homebrew** | Homebrew 自体を Nix で宣言的に管理し、tap / brew / cask を一元管理 |
| **mise** | Node.js / Ruby / Python などランタイムのバージョン管理 |

### nixpkgs を優先し、Homebrew は最小限に

パッケージは可能な限り nixpkgs から導入します。Homebrew に残すのは以下のケースに限定します。

- macOS 向け独自パッチを含む特殊な tap（例: `emacs-plus`）
- nixpkgs の当該パッケージが Linux 専用で macOS (aarch64-darwin) をサポートしていないもの（例: `libvterm`）

### Flake による入力の固定

`flake.lock` によって全ての依存バージョンを固定します。意図しないアップデートによる環境の差異を防ぎます。

---

## 新しいマシンでのセットアップ手順

> **前提**: Apple Silicon Mac (aarch64-darwin)、ユーザー名 `taguchishoh`

### 1. Xcode Command Line Tools のインストール

```sh
xcode-select --install
```

### 2. Nix のインストール

[Determinate Systems の Nix インストーラー](https://determinate.systems/posts/determinate-nix-installer) を使用します（`/etc/zshrc` などの既存ファイルへの対応が公式インストーラーより堅牢です）。

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

インストール後、シェルを再起動するか以下を実行します。

```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### 3. リポジトリのクローン

```sh
git clone https://github.com/oboro-yudachi/dotfiles-nix.git ~/dotfiles-nix
cd ~/dotfiles-nix
```

### 4. nix-darwin の初回適用

```sh
nix run nix-darwin -- switch --flake .#shounoMacBook-Air
```

初回実行時は nix-darwin 自体のセットアップも行われます。完了後は `darwin-rebuild` コマンドが使用可能になります。

### 5. 以降の設定変更の適用

設定ファイルを編集した後は以下のコマンドで反映します。

```sh
darwin-rebuild switch --flake ~/dotfiles-nix#shounoMacBook-Air
```

### 6. 動作確認

```sh
# Nix で管理されているパッケージの確認
nix profile list

# mise で管理されているランタイムの確認
mise list

# Homebrew で管理されているパッケージの確認
brew list
```
