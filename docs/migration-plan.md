> **注記（2026-08-07）**: このファイルは別端末（もう一台の Mac）で育てた nix 構成の
> 移行ログをそのまま参考資料として持ち込んだもの。ここでの `~/repo/nix` 等のパスや
> gcloud SDK・社内 AWS ツールなどはこの端末（`~/dotfiles`）の実態とは一致しない。
> 同じ種類のハマりどころ（Homebrew の cask --adopt、activation が root 実行になる話、
> doom.d の tangle 問題等）はこの端末でも再現しうるので、トラブルシュートの参照用に残す。

# Mac を nix-darwin + home-manager で管理する移行プラン

- 作成日: 2026-07-22
- 対象端末: MacBook（macOS 26.5.1 / arm64 / `/Users/taguchishoh`）
- 現在の進捗: **全 Phase（0〜7）完了**（2026-07-24）。`sudo darwin-rebuild switch --flake ~/repo/nix` で環境が再構築できる状態
  - ✅ Docker.app は復旧済み（cask 再インストール。volume 7個すべて無事）
  - 残タスクは Follow-up 節を参照（npm -g 整理 / gcloud 移設 / 退避物削除 等。いずれも急ぎでない）
- ホスト名: `shounoMacBook-Air`
- Nix: Determinate Nix 3.21.8（Nix 2.34.8）/ nix-darwin 26.05.c3e90c8
- 作業担当者: claude --resume fd410860-b32c-46d7-b8c7-1f65152d93b1

**日常の適用コマンド**

```sh
sudo darwin-rebuild switch --flake ~/repo/nix
```

各フェーズで判明した事実・判断・詰まった箇所はこのファイルに追記していく。

---

## Context

### なぜやるか
この端末の作業環境は、`~/dev/org/roam/20260710-work-environment.org` に書かれている通り「ターミナルツール10個を使いこなす」「Doom Emacs の設定を config.org 1本に集約する」という方向で独自進化してきた。しかしその実体は手続き的で再現不可能な状態にある。

調査で判明した現状の問題：

- **多重管理**: node/npm が mise・brew・npm -g の3系統に分裂。`~/.nvm`（242MB）は完全な死蔵、`.bash_profile` は未インストールの rbenv を init しようとしている。`rbenv/tap` も残骸。
- **Emacs tap が3重**: `d12frosted/emacs-plus`（実効）に加え `daviderestivo/emacs-head` と `railwaycat/emacsmacport` が tap されているだけで未使用。
- **`~/.doom.d` が git 管理外**: literate config（config.org → tangle）の最大の目的である履歴・可搬性が未達。`config.el` と `packages.el` は tangle 生成物だが、**`init.el` だけが org の外にある**。
- **zsh 補完が壊れている**: `fpath` に `/opt/homebrew/share/zsh/site-functions` が入っておらず、Homebrew 製ツールの補完が全滅。
- **PATH が二重登録**: cmux が親シェル環境を継承して `.zshrc` を再読込するため、`export PATH="...:$PATH"` のブロックが2回展開される。
- **GUI アプリが完全に非宣言的**: Arc / Cursor / DBeaver / Docker / Slack / VSCode / Karabiner / Raycast / Notion 等は手動インストールで再現性ゼロ。

### 到達点
`~/repo/nix` に置いた flake 1つから `darwin-rebuild switch` するだけで、この端末のシェル・CLI・GUI アプリ・Emacs 設定が再構築できる状態。壊れたら `--rollback` で戻せる。

### 参照する型
`https://github.com/oboro-yudachi/dotfiles-nix`（プライベート端末の成果物）の設計を土台にする。採るエッセンス：

- `nix-darwin/` と `home-manager/` の2層構成
- `nix.enable = false`（Determinate Nix と非競合にする）
- `programs.X.enable` 主体 + 一部の dotfile はそのまま配置するハイブリッド
- **`.doom.d` はディレクトリ単位で store symlink しない**（tangle が書き込めなくなるため）
- 各パッケージに「なぜ入れたか」を日本語コメントで残す文化

改善する点（参照リポジトリの弱点）：

- ホスト名・ユーザー名の7箇所ハードコード → flake.nix の `let` 1箇所に集約
- `home.nix` 単一162行 → 責務ごとに分割
- `onActivation.cleanup = "zap"` → 実務機では破壊的すぎるので `"none"` → `"check"`
- `system.defaults` 未使用 → macOS 設定も宣言化（最終フェーズ、任意）
- nixpkgs-unstable + master 追従 → 実務機なので **stable ブランチ**を採用

**このリポジトリはプライベート端末の `dotfiles-nix` とは完全に切り離す。** remote も別。あちらへ push しない。

### 確定した方針
| 論点 | 決定 |
|---|---|
| リポジトリ | **`~/repo/nix` を新規作成**。プライベート端末の public repo とは絶対に交わらせない |
| 言語ランタイム | **mise 継続**。nix は CLI ツールのみ担当。nvm / rbenv 残骸 / brew node / npm -g は撤去 |
| Emacs | **brew `emacs-plus@30` 継続**。nix-darwin の homebrew モジュールで宣言化し、`.doom.d` を git 管理して out-of-store symlink |
| literate 化 | **`init.el` も config.org に取り込む**。設定を config.org 1本に完全集約 |

### スコープ外
- org → Notion 転記関数（`my/org-notion-push`）— 別途取り組み中

---

## リポジトリ構成

```
~/repo/nix/
├── flake.nix                    # inputs / outputs。username・hostname はここの let 1箇所だけ
├── flake.lock
├── README.org                   # セットアップ手順・運用メモ
├── .gitignore
├── docs/
│   └── migration-plan.md        # ★このファイル。作業の進捗もここに追記していく
├── nix-darwin/
│   ├── configuration.nix        # トップモジュール。platform / users / nix.enable / pam / systemPath
│   ├── home_manager.nix         # home-manager の配線のみ
│   ├── homebrew.nix             # taps / brews / casks / onActivation
│   └── defaults.nix             # system.defaults（Phase 7 で追加、任意）
└── home-manager/
    ├── home.nix                 # エントリ。imports と home.username / stateVersion のみ
    ├── shell.nix                # zsh / starship / atuin / fzf / zoxide / eza / bat / direnv
    ├── git.nix                  # git / gh / delta / lazygit / difftastic
    ├── cli.nix                  # home.packages の CLI 群
    ├── emacs.nix                # doom.d の symlink と Doom 依存バイナリ
    ├── ghostty/config           # 現 ~/.config/ghostty/config を移設
    ├── cmux/cmux.json           # 現 ~/.config/cmux/cmux.json を移設
    └── doom.d/                  # ★実ディレクトリ。out-of-store symlink の実体
        ├── config.org           # ← 唯一の真実。init.el / config.el / packages.el はここから tangle
        ├── init.el              # 生成物だがブートストラップのため必ずコミット
        ├── config.el            # 生成物
        └── packages.el          # 生成物
```

**ホスト固有値の集約**（参照リポジトリの最大の弱点への対処）:

```nix
# flake.nix
let
  username = "taguchishoh";
  hostname = "<scutil --get LocalHostName の値>";  # Phase 1 で確定させる
  system   = "aarch64-darwin";
in {
  darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
    specialArgs = { inherit self username hostname; };
    modules = [ ./nix-darwin/configuration.nix ... ];
  };
}
```

各モジュールは `{ username, ... }:` で受け取る。`home_manager.nix` では `extraSpecialArgs = { inherit username; }` を渡して home-manager 側にも伝播させる。

**input の選定**（実務機なので stable）:

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
  nix-darwin  = { url = "github:nix-darwin/nix-darwin/nix-darwin-26.05"; inputs.nixpkgs.follows = "nixpkgs"; };
  home-manager = { url = "github:nix-community/home-manager/release-26.05"; inputs.nixpkgs.follows = "nixpkgs"; };
};
```

※ Phase 3 開始時に該当ブランチの実在を `nix flake metadata` で確認する。無ければ最新の stable リリースブランチへ読み替える。参照リポジトリは unstable + master 追従だが、これは意図的な乖離。

`nix-homebrew`（zhaofengli）は**当面採用しない**。単機で `/opt/homebrew` が既に稼働しており、`autoMigrate` で所有権を奪うリスクに見合う利得がない。tap の drift が問題になったら後日検討。

---

## 移行フェーズ

低リスクなものから順に。各フェーズは独立して commit し、次に進む前に必ず新しいシェルを開いて動作確認する。

### Phase 0-a — リポジトリの器を作る ✅ 完了（2026-07-22）

Nix にもシェルにも一切触れず、空のリポジトリとプラン置き場だけを作る。

1. `mkdir -p ~/repo/nix/docs && cd ~/repo/nix && git init`
2. このプランを `~/repo/nix/docs/migration-plan.md` として配置する
3. `.gitignore` を置く（`Brewfile.backup` は**あえて追跡する**ので除外しない。`result` / `.DS_Store` 等のみ）
4. 初回コミット

remote は **まだ設定しない**。設定するときも `oboro-yudachi/dotfiles-nix`（プライベート端末用・public）とは絶対に交わらせない別リポジトリにする。

README.org は運用が固まってから書く。

### Phase 0-b — 保険を作る（変更ゼロ）✅ 完了（2026-07-22）

1. ✅ `brew bundle dump --file=~/repo/nix/Brewfile.backup --force`
   → **tap 7 / brew 53 / cask 9 / mas 0 / vscode 0**、計130行。リポジトリにコミット済み。
   失敗時は `brew bundle install --file=Brewfile.backup` で全復元できる（棚卸しの一次資料も兼ねる）。
   ※ `--describe` は Homebrew 6.0 で deprecated（デフォルトで説明が入るようになった）
2. ✅ dotfiles を `~/backup-dotfiles-20260722/`（208KB）へ `cp -a`
   - 直下: `.zshrc` `.bashrc` `.bash_profile` `.gitconfig` `.gemrc` `.screenrc` `.doom.d/` `ssh-config`
   - `config/`: `starship.toml` `ghostty/` `cmux/` `atuin/` `mise/` `git/` `karabiner/` `gh-config.yml`
   - `etc/`: `zshrc` `bashrc`
3. ✅ `/etc/zshrc`（3.2KB）`/etc/bashrc`（265B）を保存。どちらも world-readable なので sudo 不要だった
4. ⚠️ APFS ローカルスナップショット `com.apple.TimeMachine.2026-07-22-202411.local` を作成
   → **同日中に macOS に purge されて消滅した**（後述）。**復元手段として数えないこと。**
   **Time Machine の宛先も未設定**（`tmutil destinationinfo` → No destinations configured）。
   **2026-07-22 の判断: Time Machine の設定は一旦見送って先に進む。**

   このスナップショットが**保険として弱い**ことは作成直後から分かっていた:

   ```
   Purgeable:  Yes                              ← macOS がいつでも消せる
   disk3s1     228Gi  176Gi used  12Gi avail  94%   ← 空きが 12GB しかない
   ```

   - APFS スナップショットは copy-on-write の「読み取り専用の断面」。撮った直後のサイズは実質ゼロで、
     以後の書き換え・削除で古いブロックが解放されずに残ることで過去の姿が保たれる
   - **同じディスク上（`disk3s1`）にある**。ディスク故障・盗難・初期化では一緒に消える。
     バックアップではなく「巻き戻しポイント」
   - **`Purgeable: Yes` かつ空き 12GB（94% 使用）**。`deleted(8)` が予告なく消す条件が揃っている。
     大きめのビルドを1回走らせただけで消えうる
   - 戻し方が粗い。個別ファイルの取り出しは `mount_apfs` での読み取り専用マウントが必要で、
     丸ごと戻すなら Recovery からボリューム全体をロールバック＝**それ以降の作業も全部消える**
   - なお `/nix` は**別の APFS ボリューム**になるので、この Data ボリュームのスナップショットには
     そもそも含まれない（Nix 自体は `/nix/nix-installer uninstall` で綺麗に消せるので実害なし）

   → **この結論を受けて Phase 1 の方針を変更した**（`rm -rf` をやめて退避ディレクトリへ `mv` する）。後述。

   **そして実際に消えた（同日中）**:

   ```
   tmutil listlocalsnapshots /                        → com.apple.os.update-* のみ
   diskutil apfs listSnapshots /System/Volumes/Data   → No snapshots for disk3s1
   ```

   `docker system prune -af` で 24GB を解放した際、スナップショットが旧状態のブロックを保持して
   肥大化し、macOS がそれを purge したものと思われる。**作成から数時間**。
   `Purgeable: Yes` の警告通りの挙動で、退避ディレクトリ方式に切り替えた判断は正しかった。
5. ✅ **BTM（Background Task Management）のロック確認 — 問題なし**

   ```
   profiles status -type enrollment
   → Enrolled via DEP: No
   → MDM enrollment: No
   ```

   実際の確認は Phase 2（Nix インストール直後）に行う。押さえておく点:
   - 確認先: システム設定 → 一般 → ログイン項目と機能拡張 → 「バックグラウンドでの実行を許可」
   - 探すのは**アプリ名ではなく「sh（不明な開発元の項目）」**。Determinate は
     `/Library/LaunchDaemons/systems.determinate.nix-installer.nix-hook.plist` を置き、
     upstream は `org.nixos.nix-daemon.plist` / `org.nixos.darwin-store.plist` を置く。
     いずれも Apple 署名がなく `/bin/sh` を実行するため、BTM には素っ気なく「sh」として2件ほど並ぶ
   - OFF なら ON にする。ON なのに daemon が動かない場合は一度 OFF→ON で BTM ストアを同期
   - 症状: 再起動後に `/nix` が空、`nix: command not found`。ボリューム自体は無傷
   - 診断（read-only）: `sudo sfltool dumpbtm | grep -B2 -A8 -iE "nixos|darwin-store"`
   - 出典: https://mgaebler.me/en/blog/nix-macos-tahoe-btm-blocks-launchdaemons/
6. ✅ `sudo -V | grep -i "secure path"` → 空。secure_path の制限なし。
   ただし**対話 sudo はこのセッション（Claude Code）からは叩けない**（パスワード入力待ちで失敗する）。
   Phase 3 以降ずっと sudo が必要な `darwin-rebuild switch` は、ユーザー自身が実行するか
   プロンプトに `! sudo darwin-rebuild ...` と打って流す

FileVault は On。既存の Nix ボリュームは無いのでクリーンな状態。

### Phase 1 — 棚卸しと掃除 ✅ 完了（2026-07-22）

nix を入れる前に、多重化と残骸を消して「宣言すべきものの正解」を確定させる。

**方針: `rm -rf` は使わず、退避ディレクトリへ `mv` する**（2026-07-22 決定）

Phase 0-b で確認した通り、APFS ローカルスナップショットは `Purgeable: Yes` かつ空き 12GB という
条件下でいつ消えてもおかしくなく、しかも個別ファイルの取り出しには `mount_apfs` が要る。
削除を取り消すのにその手順を踏むのは割に合わない。そこで:

```
mkdir -p ~/.trash-nix-migration
mv ~/.nvm ~/.bun ~/.trash-nix-migration/
```

戻すのは `mv` 一発。1〜2週間動かして問題がなければまとめて削除する（291MB 回収）。
`brew untap` / cask 削除は `Brewfile.backup` から復元できるのでそのまま実行してよい。

**実施結果**

| 対象 | 方法 | 結果 |
|---|---|---|
| `~/.nvm/`（242MB） | 退避 | ✅ `~/.trash-nix-migration/.nvm` へ。どこからも source されていない死蔵 |
| `~/.bun/`（49MB） | 退避 | ✅ `~/.trash-nix-migration/.bun` へ。`.bun/bin` は空で PATH にもない |
| `~/.bash_profile` | 退避 | ✅ 中身が `eval "$(rbenv init -)"` の1行だけ＝ファイルごと死んでいたので丸ごと退避。`bash -lc` でエラーが出ないことを確認。`.bashrc`（mise activate）はそのまま残す |
| `rbenv/tap/openssl@1.1`（20MB） | **アンインストール** | ✅ untap の前提。下記参照 |
| `brew untap rbenv/tap` | 実行 | ✅ 2 formulae / 17 files / 50.2KB |
| `brew untap daviderestivo/emacs-head` | 実行 | ✅ 7 formulae / 681 files / **566.4MB** |
| `brew untap railwaycat/emacsmacport` | 実行 | ✅ 4 casks + 4 formulae / 179 files / 24.4MB |
| `brew uninstall --cask db-browser-for-sqlite` | 実行 | ✅ `/Applications` に実体がなかった cask |
| npm -g の brew 側パッケージ | **Phase 4 へ延期** | ⚠️ 下記参照 |

**発見1: `rbenv/tap` には `openssl@1.1` がインストールされていた**

untap の前にアンインストールが必要だった。調査した結果、安全に外せると判断:

- `brew uses --installed --formula rbenv/tap/openssl@1.1` → **依存元ゼロ**
- mise の ruby（3.3.9 / 3.4.9）の `openssl.bundle` はどちらも
  `/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib` にリンク＝**openssl@3 を使っている**
- 1.1.1w は 2023-09 に EOL。rbenv で古い ruby をビルドするために入れた残骸

なお `openssl@1.1` は **`Brewfile.backup` に載っていなかった**（明示インストールではなく
依存として入っていたため `brew bundle dump` の対象外）。つまり Brewfile からは復元されないが、
誰も使っておらず EOL なので問題ない。Brewfile の差分は tap 3件 + cask 1件のみ。

**発見2: npm -g の整理は Phase 4 まで延期する（方針変更）**

当初は Phase 1 で消す予定だったが、実際に確認したところ**現役で使われていた**:

```
which -a typescript-language-server tsc difit
→ /opt/homebrew/bin/typescript-language-server
→ /opt/homebrew/bin/tsc
→ /opt/homebrew/bin/difit
```

- `typescript-language-server` は **Doom の LSP が使っている**。今消すと Phase 4 で nix が
  代替を入れるまで Emacs の TS/JS 補完が壊れる
- brew の `node` は **`jupyterlab` の依存**（`brew uses --installed --formula node` → `jupyterlab`）。
  jupyterlab は Doom の `:lang org +jupyter` が必要とするので、node を単体で外すことはできない

→ **nix 側で `typescript` / `typescript-language-server` を入れてから、brew 側を落とす**順序にする。
`difit` は mise の npm で入れ直す。

**修正するもの（Phase 4 へ）**

- `~/.screenrc`: `logfile "/Users/YourName/screen/log/..."` がテンプレ未編集、`defencodig` は `defencoding` の typo → 宣言化するついでに直す

**`~/.doom.d` の移設について（Phase 6 へ）**

当初 Phase 1 に含めていたが、**Phase 6 でまとめてやる**ことにした。移設した瞬間から Emacs が
symlink 越しに動くことになるため、tangle の挙動確認（`init.el` の org 取り込み含む）とセットで
検証したいため。

**確定した情報**

- **ホスト名: `shounoMacBook-Air`**（`scutil --get LocalHostName` / `ComputerName` とも同じ）
  → flake.nix の `hostname`、`darwinConfigurations` のキーになる
- **残った tap は4つ**: `d12frosted/emacs-plus` / `daipeihust/tap` / `manaflow-ai/cmux` / `trasta298/tap`
- **残った cask は8つ**: `cmux` `copilot-cli` `font-hack-nerd-font` `font-rambla`
  `font-symbols-only-nerd-font` `iterm2` `meetingbar` `ngrok`
- **cask 化する GUI アプリ（12個・cask 名の実在を `brew info --cask` で確認済み）**

  | アプリ | cask 名 |
  |---|---|
  | Arc | `arc` |
  | Cursor | `cursor` |
  | DBeaver | `dbeaver-community` |
  | Docker | `docker-desktop` |
  | Firefox | `firefox` |
  | Gitify | `gitify` |
  | Google Chrome | `google-chrome` |
  | Karabiner-Elements | `karabiner-elements` |
  | Notion | `notion` |
  | Raycast | `raycast` |
  | Slack | `slack` |
  | Visual Studio Code | `visual-studio-code` |

  ※ これらは Phase 5 で `homebrew.casks` に宣言する。**既に手動インストール済みなので
  `brew install` はせず、宣言だけして `cleanup = "check"` が通ることを確認する**運用でよい

- **触らないもの（MDM配布・非 cask）**: Microsoft 365 一式
  （Excel / Word / PowerPoint / Outlook / OneNote / Teams）、`Chrome Remote Desktop Host Uninstaller`、
  `Python 3.12` / `Python 3.13`（python.org インストーラ版）、`Safari`（システム）
- **`Emacs.app` は symlink** → `/opt/homebrew/opt/emacs-plus@30/Emacs.app`

**動作確認（Phase 1 後）**

- `emacs --version` → GNU Emacs 30.2。`emacs-head` / `emacsmacport` の untap は影響なし
  （どちらも formula 未インストールだった）
- `rg` `fd` `bat` `eza` `starship` `atuin` `fzf` `zoxide` `lazygit` `gh` `mise` `yazi` `delta`
  すべて解決する
- `bash -lc` がエラーを出さない

**既知の warning（Phase 1 とは無関係・対処不要）**

`brew doctor` が挙げるもの:
- `icu4c@77` が deprecated
- `imagemagick` が unlinked keg

### Phase 2 — Nix 本体だけ入れる ✅ 完了（2026-07-24）

**Determinate Systems の nix-installer をシェル形式で使う**（プライベート端末と同じ手順）:

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

**当初 `.pkg` 形式を推していたが撤回した。** `.pkg` とシェルコマンドは同じ Determinate
インストーラの配布形式違いにすぎず、入るものは同じ。避けるべきなのは「シェル形式」ではなく
**upstream の `nixos.org/nix/install`** の方だった（macOS 26.4/26.5 での失敗報告
[#15639](https://github.com/nixos/nix/issues/15639) /
[#15929](https://github.com/nixos/nix/issues/15929) はすべて upstream に対するもの）。
`.pkg` の利点として挙げていた「MDM 配下で扱いやすい」も、この端末が MDM 未登録と
判明した時点で根拠を失っていた。プライベート端末の `dotfiles-nix` README も同じ
nix-installer を指しているので、手順を揃えられる方が価値が高い。

**インストール結果**

| 項目 | 値 |
|---|---|
| バージョン | **Determinate Nix 3.21.8**（Nix 2.34.8） |
| `/nix` ボリューム | `/dev/disk3s7` に APFS でマウント（`nosuid,journaled,noatime,nobrowse,protect`）、216.6MB |
| LaunchDaemon | `systems.determinate.nix-daemon.plist` / `nix-installer.nix-hook.plist` / `nix-store.plist` の3つ |
| receipt | `/nix/receipt.json`（41KB）— **完全撤退時に使う** |
| flakes | `extra-experimental-features = nix-command flakes` で**最初から有効**（追加設定不要） |
| 動作確認 | `nix run nixpkgs#hello` → `Hello, world!`。バイナリキャッシュからの取得も動作 |

**BTM は問題なし。** `nix run` が実際に動いた＝daemon が稼働しているので、macOS 26 Tahoe の
既知問題（BTM が署名なし LaunchDaemon をブロックする）は踏んでいない。
→ **次回の再起動後に `nix --version` が通るかだけ確認すれば確定。**
消えていたら Phase 2 の BTM 項（システム設定 → 一般 → ログイン項目と機能拡張 →
「sh（不明な開発元の項目）」）を見る。

**注意点1: `/etc/zshrc` と `/etc/bashrc` が書き換えられた**

インストーラが両方に8行追記した（Phase 0-b のバックアップと diff して確認済み）:

```sh
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix
```

→ **Phase 3 で `programs.zsh.enable = true` を入れると nix-darwin が `/etc/zshrc` を
管理しようとして `Unexpected files in /etc, aborting activation` で止まる可能性がある。**
そのときは `sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin` してから再 switch。

**注意点2: `/etc/nix/nix.conf` は編集してはいけない**

冒頭に `# do not modify! this file will be replaced!` と書かれた自動生成ファイル。
設定を足すなら `/etc/nix/nix.custom.conf`（現在ほぼ空）を使う。
これは計画通り **`nix.enable = false`** にする根拠でもある（nix-darwin にも
`/etc/nix/nix.conf` を管理させると Determinate と衝突する）。

**注意点3: `nixpkgs` の既定が FlakeHub を向いている**

```
extra-nix-path = nixpkgs=flake:https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*.tar.gz
```

Determinate 特有の設定。flake の `inputs` は明示的に書くので影響しないが、
`nix run nixpkgs#...` のような即席コマンドはこちらを見る。

### Phase 3 — nix-darwin を最小構成で通す ✅ 完了（2026-07-24）

`flake.nix` + `nix-darwin/configuration.nix` を**ほぼ空**で作り、switch が通ることだけを確認した。
実際に作ったファイルはリポジトリを参照。要点:

- **stable ブランチ3本の実在を `nix flake metadata` で確認済み**
  （nixpkgs-26.05-darwin / nix-darwin-26.05 / release-26.05。いずれも直近1〜2週間以内に更新あり）
- ホスト固有値（`username` / `hostname` / `system`）は **flake.nix の `let` 1箇所に集約**し、
  `specialArgs` でモジュールへ渡す。参照リポジトリが5〜7ファイルにハードコードしていた点の改善
- `nix.enable = false`（Determinate Nix と非競合）
- `system.configurationRevision = self.rev or self.dirtyRev or null`
  → どの世代がどのコミット由来か `darwin-rebuild --list-generations` で辿れる
- `formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree`（`nix fmt` 用）

**適用手順（実際に通ったもの）**

```sh
# 1. ビルドだけ先にやって評価エラーがないか見る
nix build ".#darwinConfigurations.shounoMacBook-Air.system"

# 2. 初回ブートストラップ（darwin-rebuild がまだ PATH にない）
sudo ~/repo/nix/result/activate

# 3. 以降（ホスト名が darwinConfigurations のキーと一致するので #host は省略可）
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ~/repo/nix
```

**⚠️ 落とし穴: `result/activate` だけではシステムプロファイルが登録されない**

初回に `sudo result/activate` を直接叩いたところ、`/etc` の symlink も `/run/current-system` も
正しく設定されたが、**`/nix/var/nix/profiles/system-1-link` が作られなかった**。
プロファイルの更新は `darwin-rebuild switch` の仕事で、`activate` 単体はやらない。

この状態だと **`darwin-rebuild --rollback` も `--list-generations` も使えない**＝
世代ロールバックが機能しない。`darwin-rebuild switch --flake` で入れ直したら登録された:

```
/nix/var/nix/profiles/system      -> system-1-link
/nix/var/nix/profiles/system-1-link -> /nix/store/b4h474i...-darwin-system-26.05.c3e90c8
```

→ **初回から `darwin-rebuild switch` を使うのが正しい**
（`sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/repo/nix` でもよい）。

**`/etc` の衝突は起きなかった（事前検証済み）**

Phase 2 で「Nix インストーラが `/etc/zshrc` に8行追記したので activation が止まるかも」と
懸念したが、**杞憂だった**。nix-darwin の `activate` は既知ハッシュのリスト
（`etcSha256Hashes`）を持っていて、一致すれば安全に上書きしてよいと判断する。
このリストには**「Nix インストーラが書き換えた後」のハッシュも含まれている**。

適用前に `shasum -a 256 /etc/{zshrc,bashrc,zshenv,zprofile}` を取って照合し、4つとも
既知リストに一致することを確認してから実行した。結果、以下のように自動退避＋symlink 化された:

```
/etc/zshrc    -> /etc/static/zshrc      （+ /etc/zshrc.before-nix-darwin 3.4KB）
/etc/bashrc   -> /etc/static/bashrc     （+ .before-nix-darwin 437B）
/etc/zshenv   -> /etc/static/zshenv     （+ .before-nix-darwin 320B）
/etc/zprofile -> /etc/static/zprofile   （+ .before-nix-darwin 304B）
```

nix-darwin 版の `/etc/zshrc` にも Nix の profile.d スニペットは含まれるので `nix` は引き続き使える。

**もし衝突した場合**（今回は不要だった）:
`error: Unexpected files in /etc, aborting activation` が出たら、指摘されたファイルを
`.before-nix-darwin` を付けてリネームしてから再 switch。

**その他の地雷**:
- `sudo: darwin-rebuild: command not found` → フルパス `/run/current-system/sw/bin/darwin-rebuild`
  で叩く（この端末は sudo の secure_path 制限なしだが、初回は PATH に無いので結局フルパスが要る）
- `darwin-rebuild --list-generations` は **sudo が要る**（`/nix/var/nix/profiles/system.lock` を開くため）。
  sudo なしだと `Permission denied`
- 2025-01-30 の変更で **activation は全て root 実行**。`postUserActivation` は削除済みなので使わない

**確認できたこと**

| 項目 | 結果 |
|---|---|
| `darwin-version` | `26.05.c3e90c8` |
| 世代 | `system-1-link` が `/run/current-system` と同一 store path を指す |
| `darwin-rebuild` | `/run/current-system/sw/bin/` に配置済み |
| シェル環境 | **一切変わっていない**（`programs.zsh` も home-manager もまだ入れていないため） |

**次に足すもの**（Phase 4 以降、1つずつ switch して確認）:
- `security.pam.services.sudo_local.touchIdAuth = true;`（sudo を Touch ID で。
  旧 `security.pam.enableSudoTouchIdAuth` は削除済み）
- `programs.zsh.enable = true;`
- `environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];`

### Phase 4 — home-manager 統合と CLI の移行（本体）

#### 4-0. 配線だけ通す ✅ 完了（2026-07-24）

中身を足す前に、**空の `home.nix` で switch が通ること**だけを確認した。作ったファイルは
`nix-darwin/home_manager.nix`（配線のみ）と `home-manager/home.nix`（`username` /
`homeDirectory` / `stateVersion` / `programs.home-manager.enable` だけ）。

**`backupFileExtension` は使わない。** 既存 dotfile は手動で `mv` してから管理下に入れる。
理由: 2回目以降の activate で `.hm-bak` が既に存在すると再びエラーになる既知問題
（[home-manager#8938](https://github.com/nix-community/home-manager/issues/8938)）があり、
実務機では詰まりやすい。

**適用前の衝突チェック**（switch する前にこれをやると安全）:

```sh
# home-manager が配置しようとするファイルを列挙し、既存の実ファイルとぶつからないか見る
P=$(nix build --no-link --print-out-paths \
  ".#darwinConfigurations.shounoMacBook-Air.config.home-manager.users.\"taguchishoh\".home.activationPackage")
find "$P/home-files/" -not -type d | sed "s|$P/home-files||" | while read f; do
  [ -e "$HOME$f" ] && [ ! -L "$HOME$f" ] && echo "⚠️  衝突: ~$f"
done
```

この時点で配置されたのはマーカーファイル2つだけ:
`~/.local/state/.keep` / `~/Library/Fonts/.home-manager-fonts-version`。
`~/.zshrc` `~/.gitconfig` `~/.bashrc` は実ファイルのまま無傷、`.hm-bak` も生成されず。

**⚠️ 落とし穴: cmux では `darwin-rebuild` が PATH に現れない**

switch 後も同じ cmux セッションで `darwin-rebuild: command not found` になる。原因は
**環境変数の継承**:

```
$ env | grep __NIX_DARWIN
__NIX_DARWIN_SET_ENVIRONMENT_DONE=1
```

`/etc/zshenv` は `if [ -z "${__NIX_DARWIN_SET_ENVIRONMENT_DONE-}" ]` で
`set-environment`（`PATH` に `/run/current-system/sw/bin` を入れる）の二重実行を防いでいる。
ところが cmux は親シェルの環境をそのまま子に渡すため、**フラグだけ受け継がれて中身が入らない**。
フラグを立てた親シェル自身は activate 前に起動していたので PATH を持っていない。

対処:
- **cmux で別タブを立てる**（プロセスツリーが新しくなりフラグが消える）← これで解決した
- または フルパス `/run/current-system/sw/bin/darwin-rebuild` で叩く
- その場で直すなら `unset __NIX_DARWIN_SET_ENVIRONMENT_DONE && exec zsh`

Phase 0-b で見つけた「cmux が PATH を二重登録する」問題と同じ根っこ。
**4-1 でこれがもっと深刻な形で再発する**（brew のパスが丸ごと消える）ので、
そちらの対処も参照すること。

**`useUserPackages = true` の副作用**: home-manager の世代は
`/nix/var/nix/profiles/per-user/$USER/` ではなく **nix-darwin のシステム世代に含まれる**。
そのため `per-user/taguchishoh/` は存在しない（これは正常）。ロールバックは
`darwin-rebuild --rollback` に一本化される。

それぞれ別コミット・別 switch:

#### 4-1. `home-manager/shell.nix` — zsh 周り ✅ 完了（2026-07-24）

**⚠️ 最大の落とし穴: `environment.systemPath` を同時に入れないと brew が全滅する**

nix-darwin の `set-environment` は PATH を**追記ではなく上書き**する。既定値は:

```
$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:
/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

**`/opt/homebrew/bin` が入っていない。** この端末では `/etc/paths.d/homebrew` 経由で
PATH に入っていたので、`programs.zsh.enable` を入れた瞬間に `rg` `fd` `lazygit` `gh`
`delta` `emacs` など brew 製コマンドが軒並み `command not found` になった。

→ **`nix-darwin/configuration.nix` に必須**:

```nix
environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];
```

nix のパスが brew より前に来るので、同名コマンドは nix 版が優先される。
4-3 で `brew uninstall` した瞬間に nix 版へ切り替わる設計。

**⚠️ さらに: `environment.systemPath` だけでは cmux で効かない**

`/etc/zshenv` は `__NIX_DARWIN_SET_ENVIRONMENT_DONE` で二重実行を防いでいるが、
cmux は親シェルの環境を子に渡すため、**フラグだけ継承されて PATH が入らない**
（4-0 の落とし穴と同じ）。cmux アプリ本体が古い環境を保持していると、
新しいタブを開いても再発する。

→ **`home.sessionPath` にも同じものを書いて二重化する**。home-manager が生成する
`~/.zshenv`（正確には `hm-session-vars.sh`）は `/etc/zshenv` のフラグと無関係に動く。
PATH は `typeset -U` で重複除去されるので実害はない。

`hm-session-vars.sh` にも `__HM_SESS_VARS_SOURCED` の同種ガードがあるが、
こちらは**フラグを立てた親シェルが既に正しい PATH を持っている**ので、継承しても問題ない。
`__NIX_DARWIN_SET_ENVIRONMENT_DONE` が厄介だったのは、フラグを立てた親が
nix-darwin 導入**前**に起動していて PATH を持っていなかったため。

**移行した内容** — `~/.zshrc`（59行）の対応:

| 現状（`~/.zshrc`） | 移行先 |
|---|---|
| `EDITOR` / `VISUAL` / `LANG` | `home.sessionVariables` |
| `~/.local/bin` `~/bin` `~/.emacs.d/bin` `~/.aws-ngt-tools/bin` `/opt/homebrew/opt/mysql@8.4/bin` | `home.sessionPath`（+ 上記の `/opt/homebrew/{bin,sbin}`） |
| eza / bat の alias 5個 | `home.shellAliases` |
| `y()` yazi ラッパー | `programs.yazi.enableZshIntegration = true` が**自動生成**（手書き不要になった） |
| `aws-ngt-login` / `aws-ngt-logout` / `aws-ngt-auth status --export` | `initContent` に文字列で保持（社内ツール、実体は管理外） |
| gcloud SDK の `path.zsh.inc` / `completion.zsh.inc` の source | `initContent`。`~/Documents` 配下という非標準位置の移設は Follow-up に送る |
| `edit-command-line` + `bindkey '^Xe'` | `initContent` |

**順序制約の実装**。現行 `.zshrc` は `zoxide → mise → fzf → atuin → starship` の順で、
コメントにも「fzf より後に置くことで ctrl+r を atuin が担当」「starship（末尾に置くこと）」と
明記されていた。home-manager の各 `enableZshIntegration` は挿入順を保証しないので:

- **fzf / atuin / starship は `enableZshIntegration = false`** にして `initContent` で手書き
- fzf → atuin を `lib.mkOrder 500` の塊に、starship を `lib.mkAfter` に置く
- 順序に依存しない zoxide / yazi / direnv は `enableZshIntegration = true` に任せる

生成された `.zshrc` で順序を検証済み:
`typeset -U path`(3) → gcloud(5) → aws-ngt(15) → edit-command-line(20) → mise(25) →
**fzf(28) → atuin(29)** → compinit(38) → zoxide(39) → y()(61) → direnv(69) → **starship(77)**

**ついでに直った既存バグ**:
- `programs.zsh.enableCompletion = true` → `fpath` が正しく設定され、
  **全滅していた Homebrew 製ツールの zsh 補完が復活**
- `typeset -U path PATH` → cmux の PATH 二重登録が解消（`uniq -d` が空になることを確認）
- `~/.screenrc` の typo 等はまだ手つかず（4-4 で対応）

**設定の書き下し**:
- `programs.starship.settings` — `~/.config/starship.toml` を Nix attrset に変換
  （username 常時表示 / gcloud 有効 / nodejs・ruby・git_status 無効）
- `programs.atuin.settings` — 実質2つだけ（`enter_accept` / `sync.records`）。
  14KB の config.toml は残りが全部コメントだったので捨てた

**退避したファイル** → `~/.trash-nix-migration/phase4-1/`:
`zshrc` / `config/starship.toml` / `config/atuin/config.toml`

**動作確認**（新しいタブで実施）:

| 項目 | 結果 |
|---|---|
| `which -a rg fd lazygit gh delta emacs` | すべて `/opt/homebrew/bin/` ✓ |
| `which -a bat eza starship atuin fzf zoxide` | すべて `/etc/profiles/per-user/taguchishoh/bin/` ✓ |
| `echo $PATH \| tr ':' '\n' \| sort \| uniq -d` | 空＝重複なし ✓ |
| C-r で atuin、C-x e で edit-command-line、`ls`/`cat` のエイリアス、`y`、`gh <TAB>` | 対話確認で問題なし ✓ |

#### 4-2. `home-manager/git.nix` ✅ 完了（2026-07-24）

`programs.git` / `programs.delta` / `programs.gh` / `programs.lazygit` + `difftastic`。

**`~/.ssh/config` は管理しない**（2026-07-24 決定）。鍵ファイルと同じディレクトリにあり、
「今すぐ繋ぎたい」場面で手で書き換えることが多く、宣言化の利得が薄いため。現状維持。

**⚠️ 落とし穴1: `~/.gitconfig` は衝突検出に出ないが優先される**

home-manager は `~/.config/git/config`（XDG パス）に書くが、既存の `~/.gitconfig` は残る。
git は両方を読み、**`~/.gitconfig` が後に読まれて勝つ**。パスが違うので事前の衝突チェック
（`home.file` の list）にも現れない。→ **`~/.gitconfig` も手動退避が必須。**
`git config --list --show-origin` で「どのファイルの値が効いているか」を確認すること。

退避 → `~/.trash-nix-migration/phase4-2/`: `gitconfig` / `config/git/ignore` / `config/gh/config.yml`

**⚠️ 落とし穴2: home-manager 26.05 でオプションが大量にリネームされた**

最初 deprecation warning が5つ出た。26.05 での変更:

| 旧 | 新 |
|---|---|
| `programs.git.userName` / `userEmail` | `programs.git.settings.user.name` / `.email` |
| `programs.git.extraConfig` | `programs.git.settings`（トップレベルに統合） |
| `programs.git.delta.enable` / `.options` | **`programs.delta.enable` / `.options`**（独立モジュールに分離） |
| （delta の自動有効化） | `programs.delta.enableGitIntegration = true` を明示 |

→ 新オプションで書き直して warning ゼロに。**今後 home-manager モジュールを書くときは
`programs.git.settings.*` 形式を使う**（`extraConfig` は使わない）。

**確認できたこと**

- `git config --list --show-origin --global` → 全て `~/.config/git/config` から。`~/.gitconfig` は不参照
- `core.pager = delta`（旧）が `pager.{diff,log,blame,show}` に展開され、粒度が細かくなった
  （`git status` 等で無駄に delta を通さない）
- `gh` の credential helper が github.com / gist.github.com に自動設定された
- **`gh auth status` → keyring 認証が維持**（`hosts.yml` は触っていないため）
- `git diff` が side-by-side 表示（対話確認）
- `git` / `lazygit` / `difft` / `delta` / `gh` すべて `/etc/profiles/per-user/.../bin` 側

#### 4-3. `home-manager/cli.nix` — brew から nix へ剥がす ✅ 完了（2026-07-24）

**進め方: 1つずつ21回 switch ではなく、2ステップにした**

PATH は nix が brew より前（のはず）なので、より安全で速い形にできた:
1. nix 版を全部 `home.packages` に入れて switch → **この時点で全コマンドが nix 版に切り替わる**
   （brew はまだ残っているが PATH 後方で不使用）→ 動作確認
2. 問題なければ brew を**一括** uninstall → 壊れても `Brewfile.backup` から即復元

**移したもの（21個）**: `atuin bat eza fd ripgrep fzf jq zoxide starship git-delta
difftastic lazygit gh neovim yazi coreutils shellcheck tree-sitter screen sevenzip mise`

- `programs.X.enable` 済み（atuin/bat/eza/fzf/zoxide/starship/delta/gh/lazygit/yazi/difftastic）は
  `home.packages` に**書かない**。enable が自動でパッケージを入れる。cli.nix に新規で書いたのは
  `fd ripgrep jq neovim coreutils coreutils-prefixed shellcheck tree-sitter screen _7zz mise`
- **`sevenzip` → nixpkgs では `_7zz`**（`7zz` コマンド、同じ 26.01）
- **`coreutils-prefixed` も入れた**。無印 `coreutils` は `ls`、`coreutils-prefixed` が `gls`/`gcat`。
  Doom の dired が `gls` を使うので後者が要る（Phase 6 の先回り）

**⚠️ 4-1 由来の重大バグを発見・修正: `/opt/homebrew/bin` を sessionPath に入れると brew が nix より優先される**

ステップ1後に `which -a fd` すると **brew が nix より先**に出た。原因は 4-1 で
`/opt/homebrew/bin` を `home.sessionPath` に入れたこと。`hm-session-vars.sh` は sessionPath を
PATH の**先頭側**に prepend するため、nix profile paths より前に来ていた。
4-1 時点では brew 版と nix 版が同じツールだったので気づけなかった（動いてはいた）。

→ **修正**: sessionPath から `/opt/homebrew/{bin,sbin}` を外し、`initContent`（`typeset -U` の直後）で
`path+=(/opt/homebrew/bin /opt/homebrew/sbin)` して**末尾に**足す。これで nix が前、brew が後。
`mysql@8.4/bin` は nix に無く競合しないので sessionPath のまま。

**教訓**: cmux 対策で brew パスを二重化するときは、**必ず nix の後ろに置く**。
sessionPath は「前」に入るので使わない。initContent の `path+=` を使う。

**確認できたこと**（新しいタブで、`command -v` で実際に使われる1つを確認）:
- 21コマンドすべて `/etc/profiles/per-user/taguchishoh/bin/`（`command -v` の結果）
- `mise ls` → node 24.14.1 / ruby 3.3.9 / npm / yarn / uv すべて従来通り
  （mise の実体が brew→nix に変わっても `~/.config/mise/config.toml` と
  `~/.local/share/mise/installs/` は無傷）
- `~/.local/bin/mise`（77MB 自己更新版）を `~/.trash-nix-migration/phase4-3/` へ退避して一本化

**この時点で `brew list` は 53 → 32 に**（`Brewfile.backup` を更新済み。tap 4 / brew 32 / cask 8）。

**まだ残っている作業**:
- **npm -g の整理**（Phase 1 から延期中）。brew の `node`（jupyterlab 依存）は残したので、
  `typescript` / `typescript-language-server` / `difit` が `/opt/homebrew/lib` に残っている。
  4-3 とは別の小タスクとして後述の Follow-up 扱い
- `~/.config/mise/config.toml` は mise 自身が書き換えるので **home-manager では管理しない**（方針通り）

**brew に残すもの（Phase 5 で宣言化）**:
- `mysql@8.4` / `postgresql@16` — 既存データディレクトリとの互換を壊すリスク。brew 継続
- `gcc` / `libgccjit` / `ghc@9.12` / `z3` / `agda` — emacs-plus のネイティブコンパイルと Agda 用。brew 側でツールチェーンを揃えたままにする
- `im-select`（`daipeihust/tap`）— **nixpkgs に無い**。config.org の IME 制御が依存
- `jpeg` / `libvterm` / `poppler` / `markdown` — emacs-plus のビルド依存（参照リポジトリのコメントに理由が残っている）
- `cmake` / `automake` / `libtool` — vterm と pdf-tools のビルド用。emacs-plus が Homebrew 製なので Homebrew 側で揃える
- `keifu`（`trasta298/tap`）/ `merve` — tap 専用
- `node` — jupyterlab の依存なので残す。`tree-sitter-cli` / `tree-sitter@0.25` も未削除（Phase 6 で判断）

#### 4-4. その他の dotfile ✅ 完了（2026-07-24）

**ghostty だけ管理する**（2026-07-24 決定）。`xdg.configFile."ghostty/config".source = ./ghostty/config`。
config は現行と同一内容なので見た目は不変。退避 → `~/.trash-nix-migration/phase4-4/ghostty-config`。

**cmux と karabiner は管理外にした**。どちらも**アプリ自身が設定ファイルを書き戻す**ため、
read-only の store symlink と相性が悪い（cmux は `cmux.json.*.bak` を吐き `settings.json` を
自動生成、karabiner は `karabiner.json` を書き換える）。GUI から設定変更する頻度も低くないので、
宣言化の利得より事故リスクが上回る。管理したくなったら `mkOutOfStoreSymlink` で。

これで **Phase 4 完了**（世代は 4-0〜4-4 で複数）。シェル・git・CLI・ghostty が home-manager 管理下。

### Phase 5 — Homebrew を宣言化 ✅ 完了（2026-07-24。docker は後回し）

`nix-darwin/homebrew.nix` を作成。**`cleanup = "none"`** で開始（既存 brew を一切消さない）。
tap 4 / brew 36 / cask 18。実ファイルはリポジトリ参照。

**⚠️ `brew bundle dump` / `brew list --installed-on-request` は tap・@付き formula を漏らす**

`emacs-plus@30` / `im-select` / `keifu` は**全て on-request なのに dump・list の出力に出ない**
（`brew info --json` では on-request と確認できる）。dump を鵜呑みに宣言リストを作ると、これらが
漏れて将来 cleanup で消える。→ **手動で on-request 全件を列挙し、取りこぼし3件を full-name で追加**した。
`Brewfile.backup` にも emacs-plus@30 等が入っていなかったのはこのため。

→ **Phase 5 以降、brew の宣言的な正は `nix-darwin/homebrew.nix`。**
`Brewfile.backup`（git 追跡）は Phase 0-b〜4 の復旧用スナップショットとして保持し、これ以上更新しない。
現構成の Brewfile が欲しければ `nix eval --raw .#darwinConfigurations.<host>.config.homebrew.brewfile`。

**⚠️ 手動インストール済み GUI アプリの adopt が最大の難所**

Arc / Cursor / Chrome 等は cask ではなく手動インストールで、そのまま cask 宣言すると
brew が「未インストール」と見なして再ダウンロードを試み、既存 `.app` と競合する。回避には
`--adopt`（既存 `.app` を再取得せず cask 管理下に取り込む）が要るが、

- **`brew bundle` には `--adopt` グローバルフラグが無い**（`onActivation.extraFlags = ["--adopt"]` は
  `Error: invalid option: --adopt` で失敗した）
- **nix-darwin の cask `args` にも `adopt` キーが無い**（`args.adopt` は評価エラー）

→ **adopt は宣言では表現できず、初回だけ手動**でやるしかない:

```sh
brew install --cask --adopt arc cursor dbeaver-community firefox gitify \
  google-chrome notion raycast slack visual-studio-code
```

取り込み済みなら以降の `brew bundle` は already-installed と認識する。10個成功。

**⚠️ docker-desktop で事故: `.app` が消えた → 宣言から除外**

`docker-desktop` cask は `docker-credential-ecr-login` 等を **`/usr/local/bin`（root 所有）へ symlink**
するのに sudo を要求する。cmux の非対話 sudo では通らず、adopt が失敗 → **巻き戻しで
`/Applications/Docker.app` が削除された**。手動 `sudo -v && brew install --cask docker-desktop`
でも `/usr/local/bin/docker-credential-osxkeychain` が既存（過去の残骸）で再び失敗・`.app` 削除。

→ **docker-desktop は homebrew.nix から除外（手動管理のまま）。** switch のたびに sudo symlink で
引っかかるリスクがあるため宣言化しない。`karabiner-elements` も system extension が絡むため予防的に除外。

**✅ Docker.app 復旧済み（2026-07-24）**。原因と手順:

`/usr/local/bin` に**過去の Docker インストールが張った symlink が7個リンク切れで残っていた**
（`docker` `docker-compose` `hub-tool` `kubectl` `kubectl.docker` `docker-credential-desktop`
`docker-credential-osxkeychain`）。docker cask はこれら全てを張ろうとし、**1つでも既存があると
失敗して巻き戻し、その過程で `/Applications/Docker.app` を削除する**。もぐら叩きになったので、
cask が張る全ターゲットを先に退避してから再インストールした:

```sh
sudo mv /usr/local/bin/{docker,docker-compose,hub-tool,kubectl,kubectl.docker,\
  docker-credential-desktop,docker-credential-osxkeychain} /usr/local/.trash-docker/
sudo -v && brew install --cask docker-desktop   # sudo -v で先にキャッシュ
```

結果:
- **volume 7個すべて無事**（`myapp_mysql_volume` 等。DB データは失われていない）
- コンテナは空になった（`.app` 削除でコンテナ定義がリセット）が、`docker compose up` で
  既存 volume を使って再作成されるので実害なし
- **docker-desktop は cask 管理下に入ったが `homebrew.nix` では宣言しない**（`cleanup="none"` の間は
  switch で触られない）。`cleanup="check"` に上げるときに「宣言外 cask」として出るので、
  そのとき手動管理を続けるか宣言に戻すか判断する
- 起動中エンジンが 4.72.0 表示（入れた cask は 4.83.0）。Docker Desktop 再起動で揃う。動作に支障なし

**cleanup 運用**:
1. ✅ `cleanup = "none"` で宣言と実体を一致させた
2. ✅ **`"check"` に昇格**（2026-07-24）。宣言漏れが activation エラーで可視化される。**削除はしない**。
   switch が通った＝**宣言と実体が完全に一致している証明**。以後、宣言外の brew が増えたら switch が教えてくれる
3. ⬜ その後 `"uninstall"` を検討。`"zap"` は cask 設定まで消すので実務機では常用しない
   - 低レベル依存（gmp / openssl@3 / autoconf 等）を brews に明示列挙してあるのは、
     `"check"` で「宣言外」として弾かれないための保険

**`"check"` 昇格時に判明した2点**（2026-07-24）:

- **`sdl2-compat` を明示宣言する必要があった**。`ffmpeg-full` / `whisper-cpp` の依存なのに
  cleanup が削除対象と誤判定した。原因は **brew のエイリアス解決**: 依存側は `sdl2`（エイリアス）を
  要求するが、実際にインストールされているのは `sdl2-compat`（実名）で、cleanup が両者を同一視できず
  「宣言から辿れない」と見なす。消すと ffmpeg-full が壊れるので brews に明示追加した
- **`docker-desktop` を宣言に戻した**。Phase 5 で除外したが、`"check"` では宣言外＝エラーになるため。
  除外の理由だった事故は「**未インストール状態から install** して `/usr/local/bin` の symlink 衝突 →
  巻き戻しで `.app` 削除」だったが、現在は installed かつ symlink も存在するので
  `brew bundle` は already-installed として skip する（`upgrade = false` なので更新も走らない）。
  実際に switch して問題なしを確認。`karabiner-elements` は引き続き除外（system extension のため）

**事前検証の方法**（`"check"` に上げる前にこれをやると安全）:

```sh
# 宣言される Brewfile を書き出して、cleanup 対象が残らないか dry-run で見る
nix eval --raw '.#darwinConfigurations.<host>.config.homebrew.brewfile' > /tmp/Brewfile.declared
brew bundle cleanup --file=/tmp/Brewfile.declared   # --force を付けなければ削除されない
```

`Would uninstall casks:` / `Would uninstall formulae:` が出なければ通る。
`Would remove:`（古いバージョン・キャッシュ・空ディレクトリ）は無害。
※ `brew bundle check` は別物で、こちらは「outdated かどうか」も報告するので紛らわしい
（`needs to be installed or updated` は未インストールとは限らない）。

**確認できたこと**（switch 後、世代11）:
- tap trust 対象（emacs-plus@30 / im-select / keifu）は健在。`brew bundle` は Brewfile の
  `trusted: true` により tap trust をパスした（手動 install では warning が出ていた）
- GUI cask 10個すべて cask 管理下
- formula 205 は不変（`cleanup = "none"`）、cask は 8 → 18
- `Karabiner-Elements.app` 健在（宣言外だが手動インストール分は残る）

**その他メモ**:
- `homebrew.brewPrefix` は 2026-02-10 に `homebrew.prefix` に改名（意味も `/opt/homebrew/bin` →
  `/opt/homebrew`）。今回は使っていない
- `masApps` は「オプションから消してもアンインストールされない」制限があるので不使用
- GUI アプリを **nix ではなく brew cask に残す**方針は維持（nix の `.app` は Spotlight 非対応）

### Phase 6 — Doom Emacs の宣言化と config.org 集約

ここがこの端末の「独自進化」の中核。

**実施順は計画と変えた（2026-07-24）**: 先に config.org 1本化（init.el 取り込み）を
`~/.doom.d` の現在地で済ませて `doom sync` が通ることを確認し、**動く状態のものをリポジトリへ移した**。
逆順（先に symlink）だと問題が出たとき「symlink のせいか tangle のせいか」切り分けにくいため。

#### 6-1. config.org に init.el を取り込んで1本化 ✅ 完了（2026-07-24）

config.org 末尾に `* Init` セクションを追加し、`:header-args:emacs-lisp: :tangle init.el` を付けて
現行 init.el（doom! マクロ 183行）をそのまま埋め込んだ。既存の `* Packages`（`:tangle packages.el`）と
同じパターン。

**検証手順（tangle が現行と一致するか、移す前に確認）**:
```sh
# 素の org で batch tangle（:tangle 指定のあるブロックだけ = init.el / packages.el）
emacs --batch -l org --eval \
  '(let ((default-directory (expand-file-name "~/.doom.d/"))) \
     (org-babel-tangle-file (expand-file-name "~/.doom.d/config.org")))'
diff <backup>/init.el ~/.doom.d/init.el   # → 完全一致を確認
```

- 素の org は `:tangle` 指定のあるブロックだけ tangle する（config.el 用ブロックは指定が無く、
  literate モジュールがデフォルト先として config.el を渡すので batch では対象外）。だから
  「Tangled 2 code blocks」= init.el + packages.el。config.el は本番の `doom sync` が生成
- **生成 init.el は現行と完全一致**（SHA 一致）。doom sync でも同結果を確認
- **鶏卵問題**: Doom は config.org より先に init.el を読むため、init.el が無いと `:config literate` が
  効かず tangle が走らない。→ 生成物（init.el / config.el / packages.el）は `.gitignore` せず必ずコミット

#### 6-2. `~/.doom.d` を out-of-store symlink でリポジトリ管理下へ ✅ 完了（2026-07-24）

`config.org` / `config.el` / `init.el` / `packages.el` を `repo/home-manager/doom.d/` へコピーし、
`emacs.nix` で `mkOutOfStoreSymlink` を張った:

```nix
home.file.".doom.d".source =
  config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repo/nix/home-manager/doom.d";
```

- `~/.doom.d` → `repo/home-manager/doom.d`（**書き込み可能な実ディレクトリ**）。
  home.file の通常 source（read-only な /nix/store symlink）だと tangle 出力を書けず破綻する
- switch 後 `doom sync` → **`Done tangling 3 file(s)!`**（read-only エラーなし＝書き込み成功）、
  `All 256 packages up-to-date`。`git status` で `home-manager/doom.d/` に差分が出る
  ＝tangle 出力がそのまま git 作業ツリーに落ちる
- `.claude/settings.local.json`（Claude Code のローカル設定）は含めず、`.gitignore` に
  `home-manager/doom.d/.claude/` を追加
- 退避 → `~/.trash-nix-migration/phase6-2/doom.d`（中身は repo にコピー済み）

#### 6-3. Doom 依存バイナリの整理 ✅ 完了（2026-07-24）

`doom doctor` で健全性を確認し、分担を確定した。

**結論: emacs-plus エコシステムは brew で完結、実行系 CLI は nix。新規 nix 移行はほぼ無し。**

- **pandoc は jupyterlab の依存、gnupg は gpgme/gpgmepp/poppler の依存**で brew から外せない。
  nix に入れると二重管理になるので移さない。gpg-agent は brew の pinentry-mac と連携済み
  （`~/.gnupg/gpg-agent.conf` → `pinentry-program /opt/homebrew/bin/pinentry-mac`）
- emacs-plus@30 のビルド／連携チェーン（gcc / libgccjit / cmake / automake / libtool /
  libvterm / jpeg / poppler / markdown）も brew（Phase 5 で宣言済み）
- 実行系 CLI（rg / fd / difftastic / shellcheck / coreutils / tree-sitter）は Phase 4 で nix 済み

**nix で新規に足したもの**（`doom doctor` が要求、実用機能に直結）:
- `pngpaste`（org-download-clipboard）/ `graphviz`（dot: org-roam グラフ）/ `nixfmt`
  → `home-manager/emacs.nix` の `home.packages`
- `symbola`（Emacs フォールバックフォント）→ `nix-darwin/configuration.nix` の `fonts.packages`。
  **unfree なので `nixpkgs.config.allowUnfreePredicate` で symbola だけ許可**（`allowUnfree = true` は
  広すぎるので使わない）

**残した doom doctor 警告**（その言語/機能を使うときに足す。このマシンは Rails+React 中心）:
haskell-language-server / hoogle / cabal / lake(Lean) / composer・php / rust-analyzer /
stylelint・js-beautify(web フォーマッタ)。`annalist.elc out-of-date` は次の doom sync で解消。

これで **Phase 6 完了**。Doom 設定が config.org 1本に集約され、リポジトリ管理下・自動 tangle も動作。

---

以下は Phase 6 の元計画（設計判断の記録として残す）。

**6-1. `.doom.d` を out-of-store symlink で配置**

`config.org` を保存すると literate モジュール（`+literate-enable-recompile-h`）が自動で再 tangle し、`doom sync` のたびにも tangle が走る。つまり **`$DOOMDIR` は書き込み可能な実ディレクトリでなければならない**。しかも `init.el` を tangle 対象にすると生成物が3つ（`init.el` / `config.el` / `packages.el`）になり、参照リポジトリのようなファイル個別 `home.file` symlink では全部書き込み不可になって破綻する。

したがって **ディレクトリごと out-of-store symlink** にする:

```nix
# home-manager/emacs.nix
{ config, ... }: {
  home.file.".doom.d".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repo/nix/home-manager/doom.d";
}
```

これで `~/.doom.d` → `~/repo/nix/home-manager/doom.d`（実ディレクトリ）となり、tangle 出力がそのまま git 作業ツリーに落ちる。`git status` で「config.org を編集したら生成物も変わった」ことが見える。

`~/.emacs.d`（Doom 本体、`.local` が 1.3GB）は **完全に管理外**。straight が MELPA HEAD を clone する非決定的な領域なので home-manager は一切触らない。

**6-2. `init.el` を config.org に取り込む**

config.org に `* Init` 見出しを作り、`:PROPERTIES: :header-args:emacs-lisp: :tangle init.el :END:` を付けて現行 `init.el`（183行、`doom!` マクロとモジュール一覧）を移す。既存の `* Packages` 見出しが同じパターン（`:tangle packages.el`）を使っているので踏襲するだけ。

**鶏卵問題への対処**: Doom は `config.org` より先に `init.el` を読む。つまり `init.el` が無い状態からはブートストラップできない。→ **生成された `init.el` / `config.el` / `packages.el` は `.gitignore` せず必ずコミットする**。README にこの理由を明記する。

**tangle パスの絶対化**: `:tangle packages.el` は `default-directory` 依存で、エディタから `C-c C-v t` を手で叩くとカレントディレクトリ次第で出力先がずれる。literate モジュール経由なら `~/.doom.d` に落ちるが、`:tangle "~/.doom.d/packages.el"` のように絶対化するか、tangle 時に `default-directory` を明示する方が堅い。

**6-3. Emacs バイナリと依存**

`homebrew.brews` に `d12frosted/emacs-plus/emacs-plus@30` を宣言（Phase 5 で済ませてある）。`/Applications/Emacs.app` は `/opt/homebrew/opt/emacs-plus@30/Emacs.app` への symlink で、参照リポジトリ同様 `system.activationScripts.postActivation` で張り直してもよい。

Doom が必要とする外部バイナリ（すでにインストール済み・実際に使われているもの）:

| バイナリ | 用途 | 移行先 |
|---|---|---|
| `rg` / `fd` | Doom 必須 | nix (Phase 4) |
| `pandoc` | AUTO_EXPORT の org→GFM 経路、`:lang org +pandoc` | nix |
| `gnupg` / `pinentry-mac` | `:lang org +crypt`、auth-source（`~/.authinfo.gpg`） | nix |
| `difftastic` | config.org の difftastic 統合 | nix |
| `gnuplot` / `jupyter` / `zeromq` | `:lang org +gnuplot +jupyter` | nix（jupyterlab は brew 継続でも可） |
| `shellcheck` / `coreutils`(gls) | `:lang sh` checker / dired | nix |
| `im-select` | config.org の IME 制御 | **brew 必須**（nixpkgs に無い） |
| `cmake` / `libtool` / `libvterm` | vterm のネイティブビルド（claude-code-ide のバックエンド） | brew 継続 |
| `gcc` / `libgccjit` | native-comp（emacs-plus が rpath 参照） | brew 継続 |
| `poppler` / `automake` | pdf-tools（**現状 epdfinfo が未ビルド**） | brew 継続 |
| `mysql` client | config.org の `ob-sql` ヘルパー | brew 継続 |
| Hack Nerd Font Mono | `doom-font` | cask（`nerd-fonts.hack` で nix 化も可） |

`~/bin/install-doom-emacs.sh` は実環境と乖離している（`~/.config/emacs` + `~/.config/doom` 前提だが実体は `~/.emacs.d` + `~/.doom.d`。フォントも `font-fira-code` を入れるが実際は Hack Nerd Font）。宣言化が済んだら `install-doom-emacs.sh` / `uninstall-doom-emacs.sh` は**破棄する**（後者は `rm -rf` を含むので特に）。

**6-4. `doom sync` は activation に入れない**

`home.activation` に `doom sync` を挿すと、straight のネットワーク clone と native-comp (AOT) で `darwin-rebuild switch` が数分〜数十分ブロックし、失敗時に switch 全体がロールバックされて Emacs だけ半端な状態で残る。**手動運用にする**。README に「config.org の `* Packages` を変えたら `doom sync`」と明記。

### Phase 7 — macOS システム設定の宣言化 ✅ 完了（2026-07-24）

参照リポジトリが持っていない領域。`nix-darwin/defaults.nix` を新規作成。
**ユーザーが選んだのは「現状のカスタムを固定」+「キーリピート最速化」の2つ**（スクショ専用フォルダ・
ダークモード固定は今回見送り）。

宣言した内容（実機の現状値を `defaults read` で拾って固定 + キーリピートのみ変更）:

| ドメイン | キー | 値 | 備考 |
|---|---|---|---|
| NSGlobalDomain | `ApplePressAndHoldEnabled` | false | キー長押しでアクセントメニューを出さない（vim 等） |
| NSGlobalDomain | `InitialKeyRepeat` / `KeyRepeat` | 15 / 2 | ★キーリピート最速化（唯一の変更。再ログインで反映） |
| NSGlobalDomain | `com.apple.trackpad.scaling` | 2.5 | トラッキング速度（現状固定） |
| dock | `autohide` / `tilesize` / `magnification` / `orientation` | true / 57 / true / bottom | 現状固定 |
| finder | `FXPreferredViewStyle` | `clmv` | カラム表示 |
| finder | `FXDefaultSearchScope` | `SCev` | **This Mac（全体検索）**。現状のまま |
| trackpad | `Clicking` | true | タップでクリック |

- 再ログインまで反映されない項目があるので、`system.activationScripts.postActivation` で
  `activateSettings -u` を叩いて即時反映（キーリピートだけは再ログインが必要）
- 型付きオプションに無いものは `system.defaults.CustomUserPreferences` で任意ドメインに書ける（今回は未使用）
- 限界: TCC 保護領域（フルディスクアクセス / 画面収録 / アクセシビリティ）は宣言不能。
  Karabiner の権限などはここに含まれる

**Touch ID for sudo も同時に有効化**（`configuration.nix`）:

```nix
security.pam.services.sudo_local.touchIdAuth = true;
```

`/etc/pam.d/sudo_local` に `pam_tid.so` を入れる。`darwin-rebuild switch` のたびの sudo が
Touch ID になった（動作確認済み）。macOS アップデートで上書きされても再 switch で復活する。
旧 `security.pam.enableSudoTouchIdAuth` は削除済み。
**注**: tmux / screen 内で sudo する場合はセッションが切り離されて Touch ID が効かず、
`pam_reattach` の追加が必要。cmux / iTerm 直なら不要。

---

## 検証

各フェーズ後に**新しいシェルを開いて**確認する（既存シェルは古い環境を持っている）。

**Phase 3 後**
```
sudo darwin-rebuild switch --flake ~/repo/nix#<hostname>   # 成功すること
darwin-rebuild --list-generations                          # 世代が記録されていること
```

**Phase 4 後**
```
which -a rg bat eza starship atuin fzf zoxide
  → /etc/profiles/per-user/taguchishoh/bin/... を指していること
echo $PATH | tr ':' '\n' | sort | uniq -d
  → 空（重複なし = typeset -U が効いている）
```
- Ctrl+R で atuin の履歴検索が出る（fzf に奪われていない）
- Ctrl+X e で `edit-command-line` が起動する
- `ls` / `ll` / `la` / `lt` が eza、`cat` が bat
- `y` で yazi が起動し、終了時に cd する
- `git diff` が delta で side-by-side 表示される
- `gh <TAB>` / `mise <TAB>` で補完が効く（**現状壊れているものが直る**）
- `mise ls` で node 24.14.1 / ruby 3.3.9 が従来通り解決される
- `aws-ngt-login` が動く

**Phase 5 後**
```
brew bundle check --file=$(readlink /etc/homebrew/Brewfile 2>/dev/null || echo ~/repo/nix/Brewfile.backup)
```
`cleanup = "check"` に切り替えて switch が通れば宣言が完全。エラーが出たら宣言漏れをリストに追加する（**この段階では何も消されない**）。

**Phase 6 後**
```
emacs --version                      # 30.2
doom sync                            # 成功すること
doom doctor                          # 新規のエラーが出ていないこと
```
- Emacs で `~/.doom.d/config.org` を開いて編集・保存 → `init.el` / `config.el` / `packages.el` が再生成される
- `cd ~/repo/nix && git status` で生成物の差分が見える
- `~/.doom.d` が `~/repo/nix/home-manager/doom.d` への symlink になっている（`ls -la ~/.doom.d`）
- org-roam が `~/dev/org/` を認識し、`~/.emacs.d/.local/cache/org-roam.db` が残っている（全ノード再スキャンが走っていない）
- vterm と claude-code-ide が起動する
- `~/dev/org/roam/` のノートから `AUTO_EXPORT`（pandoc 経由）が動く

ロールバック・復元は次章にまとめた。

---

## 復元手順

**⚠️ 大前提: APFS ローカルスナップショットは当てにできない（実証済み）**

Phase 0-b で作成した `com.apple.TimeMachine.2026-07-22-202411.local` は、**同日中に macOS に
purge されて消滅した**。

```
tmutil listlocalsnapshots /            → com.apple.os.update-* のみ
diskutil apfs listSnapshots /System/Volumes/Data  → No snapshots for disk3s1
```

おそらく `docker system prune -af` で 24GB を解放した際、スナップショットが旧状態のブロックを
保持することで肥大化し、それを macOS が purge したもの。`Purgeable: Yes` の警告通りの挙動で、
**作成から数時間で消えた**。Time Machine の宛先が未設定である以上、スナップショットは
復元手段として数えないこと。

→ **実際に効く復元手段は以下の4つだけ。**

### 1. Phase 1 で退避したもの — `~/.trash-nix-migration/`

`mv` で戻すだけ。最も確実。

```bash
mv ~/.trash-nix-migration/.nvm  ~/           # 242MB, node v24.11.0
mv ~/.trash-nix-migration/.bun  ~/           # 49MB
mv ~/.trash-nix-migration/bash_profile ~/.bash_profile   # ★先頭のドットが無いので注意
```

`bash_profile` は退避時にドットが落ちている（`mv ~/.bash_profile <dir>/bash_profile`）。
戻すときはファイル名を明示すること。中身は `eval "$(rbenv init -)"` の1行のみ。

**このディレクトリは 2026-08 上旬まで残す。** 問題がなければ `rm -rf ~/.trash-nix-migration`
で 291MB 回収。

### 2. dotfiles — `~/backup-dotfiles-20260722/`

Phase 0-b で `cp -a` したもの。208KB。中身:

```
.bash_profile  .bashrc  .doom.d/  .gemrc  .gitconfig  .screenrc  .zshrc  ssh-config
config/  → atuin/ cmux/ gh-config.yml ghostty/ git/ karabiner/ mise/ starship.toml
etc/     → bashrc  zshrc
```

```bash
B=~/backup-dotfiles-20260722
cp -a "$B/.zshrc" ~/.zshrc                       # 個別に戻す
cp -a "$B/.doom.d" ~/.doom.d                     # Doom 設定一式
cp -a "$B/config/starship.toml" ~/.config/
cp -a "$B/ssh-config" ~/.ssh/config              # ★ここもファイル名が違う
sudo cp -a "$B/etc/zshrc" /etc/zshrc             # nix-darwin が壊した場合
```

`~/.doom.d` は Phase 6 で移設するので、**移設に失敗したらここから丸ごと戻せる**。

### 3. Homebrew — `~/repo/nix/Brewfile.backup`

```bash
brew bundle install --file=~/repo/nix/Brewfile.backup   # 宣言されたもの全部を復元
brew bundle check   --file=~/repo/nix/Brewfile.backup   # 差分の確認だけ
```

git 追跡しているので、**掃除前の状態に戻したければ過去のリビジョンを取り出す**:

```bash
cd ~/repo/nix
git show 4b8a842:Brewfile.backup > /tmp/Brewfile.before-cleanup   # Phase 1 実施前
brew bundle install --file=/tmp/Brewfile.before-cleanup
```

| リビジョン | 状態 |
|---|---|
| `4b8a842` | Phase 1 実施**前**（tap 7 / brew 53 / cask 9） |
| `855d576` | Phase 1 実施**後**（tap 4 / brew 53 / cask 8） |

**Brewfile から復元されないもの**: `rbenv/tap/openssl@1.1`。依存として入っていたため
`brew bundle dump` の対象外だった。必要になったら `brew tap rbenv/tap &&
brew install rbenv/tap/openssl@1.1`（ただし EOL なので推奨しない）。

### 4. Docker — 再ビルド / 再 pull

`docker system prune -af` で 24.39GB 回収した際に消えたもの。**ボリューム7つは全て無傷**
（`--volumes` を付けなかったため）なので、DB データは失われていない。

| 消えたもの | 復元方法 |
|---|---|
| `myapp-storybook` | `cd ~/dev/myapp && docker compose build storybook` |
| `myapp-ngt2026-team1-web` / `team2-web` | 各プロジェクトで `docker compose build`。ボリューム `myapp-ngt2026-team{1,2}_mysql_data` は残存 |
| `mysql:8.0` / `mysql:8.0.31` | `docker pull mysql:8.0` 等 |
| `nix-demo` / `docker/welcome-to-docker` | 不要（実験・サンプル） |
| build cache 13.6GB | 次回ビルド時に再生成される |

稼働中の5コンテナ（`myapp-app` / `myapp-redis` / `myapp-db` / `myapp-playwright-1` /
`myapp-session_redis-1`）は無事。削除された `myapp_default` ネットワークは孤児で、
実際に使われているのは `myapp_network`。

### 5. nix-darwin の世代ロールバック（Phase 3 以降）

```bash
sudo darwin-rebuild --list-generations                # ★sudo 必須（system.lock を開くため）
sudo darwin-rebuild --rollback                        # 直前の世代へ
sudo /nix/var/nix/profiles/system-<N>-link/activate   # 特定世代へ
```

**前提: `darwin-rebuild switch` で適用していること。** `result/activate` を直接叩くと
`/nix/var/nix/profiles/system-N-link` が作られず、この節の手段が一切使えない（Phase 3 で実際に踏んだ）。
`ls -la /nix/var/nix/profiles/ | grep system` で世代が並んでいるか確認できる。

**Phase 3 以前に戻すなら**、`/etc` の退避ファイルから手で戻す:

```bash
sudo mv /etc/zshrc.before-nix-darwin   /etc/zshrc
sudo mv /etc/bashrc.before-nix-darwin  /etc/bashrc
sudo mv /etc/zshenv.before-nix-darwin  /etc/zshenv
sudo mv /etc/zprofile.before-nix-darwin /etc/zprofile
```

**世代管理では戻らないもの**（上記 1〜4 の手段で手動復旧する）:
- `homebrew.onActivation.cleanup` がアンインストールした brew パッケージ → **3.**
- `system.defaults` で書いた macOS 設定値 → 手動で戻す
- home-manager が退避／上書きした dotfile → **2.**

### 6. 完全撤退（Nix ごと消す）

```bash
sudo darwin-uninstaller           # nix-darwin を先に外す
/nix/nix-installer uninstall      # Determinate installer の receipt で巻き戻す
```

- 既知バグ: uninstaller が `/etc/zshrc` / `/etc/bashrc` を復元し損ねる
  → `~/backup-dotfiles-20260722/etc/` から戻す（**2.** 参照）
- **⚠️ 「Nix が消えた」ように見えても `diskutil` でボリュームを削除しないこと。**
  Nix store ごと不可逆に消える。まず「マウントされていないだけ」「BTM にブロックされているだけ」
  を疑う（Phase 2 の BTM 項を参照）

---

## Follow-up（今回のスコープ外だが記録）

- ✅ **npm -g の brew 側パッケージ整理**（完了 2026-07-24）: Phase 1→4 から延期していたもの。
  brew の `node` は jupyterlab の依存なので残したまま、グローバルパッケージだけ整理した。

  | コマンド | 移行後 | バージョン |
  |---|---|---|
  | `tsc` | nix（`cli.nix`） | 5.9.3（brew と同じ） |
  | `typescript-language-server` | nix（`cli.nix`） | 5.1.3 → **5.3.0** |
  | `difit` | mise の npm（nixpkgs に無い） | 3.0.1 → **5.0.8** |

  手順: cli.nix に typescript / typescript-language-server 追加 → switch で nix 版が PATH 優先に →
  `/opt/homebrew/bin/npm uninstall -g typescript typescript-language-server difit` →
  mise の npm で difit を入れ直し（mise が自動で reshim）。
  `/opt/homebrew/lib` は `npm` のみになり三重管理が解消。Doom の TS/JS LSP 動作確認済み。
- ✅ **gcloud SDK の移設**（完了 2026-07-24）: `~/Documents/google-cloud-sdk`（706MB）を
  `~/.local/share/google-cloud-sdk` へ `mv`。`shell.nix` の source パスも更新。

  **当初の移設理由（iCloud 同期リスク）は成り立たなかった**。調べたところ
  `~/Library/Mobile Documents/com~apple~CloudDocs` が存在せず iCloud Drive 自体が無効。
  実際の理由は「`~/Documents` はドキュメント置き場で SDK の場所として非標準」という整理のみ。

  **再認証は不要だった**。認証・設定は `~/.config/gcloud`（84MB）側にあり、SDK 本体の移動では
  失われない。移設後も `gcloud auth list` でアカウントが維持されていることを確認済み。
  SDK は絶対パス依存が無い作りで、バージョン（576.0.0）も変わらず動作。

  なお `nixpkgs` の `google-cloud-sdk` に寄せる案もあったが、`gcloud components` で入れた
  追加コンポーネントの入れ直しとバージョン変更が発生するため見送り（手動管理を継続）。
- **`org-roam-db-location` が未指定**: Doom デフォルトの `~/.emacs.d/.local/cache/org-roam.db` に置かれている。`$EMACSDIR` を将来動かすと DB が消えたように見えて全ノード再スキャンになるので、`~/.local/share/org-roam/org-roam.db` 等の安定パスを config.org で明示しておくとよい
- **`doom env`（`.local/env`）にセッション固有値が焼き込まれている**（`CMUX_SURFACE_ID` 等）。再現性がないので、必要な環境変数は config.org 側で `setenv` するのが筋
- **`~/dev/org/` は別リポジトリ**（`oboro-yudachi/org`）。可変データなので nix 管理下に置かない。config.org 側のパス指定だけを宣言化する
- **`~/bin/rspec.sh`** は Raycast Script Command で myapp のパスをハードコード。Raycast 側の管理領域として管理外
- `.npm`（1.0GB）/ `.yarn`（504MB）/ `.gem`（63MB）のキャッシュ肥大 — 掃除の余地
- **⚠️ myapp の `ruby-lsp-rails` が `mysql2` 読み込みで落ちることがある**（2026-08-04）:
  `Bundler::GemRequireError` / `Library not loaded: /opt/homebrew/opt/mysql/lib/libmysqlclient.24.dylib`。
  原因は `mysql2` gem のネイティブ拡張が無印 `mysql`（brew）へのリンクを埋め込んでビルドされて
  いるが、このリポジトリでは `mysql@8.4`（`homebrew.nix`）しか管理していないため `/opt/homebrew/opt/mysql`
  自体が存在しないこと。nix 側の設定ミスではなく、myapp 側の `mysql2` gem を `mysql@8.4` 向けに
  再ビルドすれば直る（`.bundle/config` は myapp の `.gitignore` 対象なのでこのリポジトリには残らず、
  新しい clone や `mysql@8.4` のバージョンアップ後は再発しうる）。

  ```sh
  cd ~/dev/myapp
  bundle config build.mysql2 --with-mysql-config=/opt/homebrew/opt/mysql@8.4/bin/mysql_config \
    --with-ldflags="-L/opt/homebrew/opt/zstd/lib -L/opt/homebrew/opt/openssl@3/lib"
  bundle pristine mysql2
  ```

---

## 調査の一次資料

### 参照リポジトリ（プライベート端末）
https://github.com/oboro-yudachi/dotfiles-nix — 12ファイル・約1,175行のフラット構成。`nix-darwin/{configuration,home_manager,homebrew}.nix` + `home-manager/home.nix`（単一162行）+ 生 dotfile（`git/.gitconfig`, `ghostty/config`, `doom.d/*`）。

### nix-darwin / home-manager の破壊的変更（踏むと詰まるもの）
- 2026-02-10: `homebrew.brewPrefix` → `homebrew.prefix`（意味も変更）。`onActivation.cleanup = "check"` 追加
- 2025-01-30: activation が全て root 実行に。`system.activationScripts.{extraUserActivation,preUserActivation,postUserActivation}` 削除。`system.primaryUser` 必須化
- 2025-01-29: `nix.enable` トグル追加
- `security.pam.enableSudoTouchIdAuth` → `security.pam.services.sudo_local.touchIdAuth`
- `fonts.fonts` → `fonts.packages`、`fonts.fontDir.enable` は削除

### macOS 26 (Tahoe) 固有の地雷
- **BTM が署名なし LaunchDaemon をブロック** → https://mgaebler.me/en/blog/nix-macos-tahoe-btm-blocks-launchdaemons/
- upstream インストーラの 26.4 失敗（nixbld group has no members, 未解決）→ https://github.com/nixos/nix/issues/15639
- upstream インストーラの 26.5 SSL 証明書検証エラー → https://github.com/nixos/nix/issues/15929
- Determinate の復旧手順 → https://docs.determinate.systems/troubleshooting/nix-disappeared-from-macos/
- **⚠️ 「Nix が消えた」ときに `diskutil` でボリューム削除を提案されても実行しない**（Nix store ごと不可逆に消える）。まず「マウントされていないだけ」を疑う

### その他の主要出典
- nix-darwin README / CHANGELOG: https://github.com/nix-darwin/nix-darwin
- home-manager on nix-darwin: https://nix-community.github.io/home-manager/installation/nix-darwin.html
- `backupFileExtension` の2回目 clobber 問題: https://github.com/nix-community/home-manager/issues/8938
- homebrew モジュール: https://github.com/nix-darwin/nix-darwin/blob/master/modules/homebrew.nix
- Determinate + nix-darwin: https://docs.determinate.systems/guides/nix-darwin/
