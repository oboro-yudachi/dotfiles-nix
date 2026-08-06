# Doom Emacs の起動が遅い件の調査 log

- 対象: MacBook（macOS 26 / arm64）の emacs-plus@30 + Doom Emacs
- 関連ファイル: `home-manager/emacs.nix`, `home-manager/git.nix`, `home-manager/doom.d/`
- ステータス: **未解明**（20〜24 秒の遅さはまだ再現・特定できていない）

このファイルは「emacs.nix のコメントに書くには長すぎる調査の歴史」を退避する場所。
結論が出ていない話・後で否定された仮説も、同じ轍を踏まないためにそのまま残す。

---

## 症状

Mac を再起動した後の **初回 GUI 起動だけ** 20〜24 秒かかる。
2 回目以降や、しばらく使った後は速い。

---

## 第1幕: 「コールド I/O が原因」説（commit 3e686fe）と、その対策

最初の調査で「~/.emacs.d 配下 1.4GB（straight 1.1GB + eln 269MB、小ファイル多数）を
コールドなページキャッシュから読み直す I/O が支配的」と結論し、以下を入れた:

- **launchd で emacs daemon をログイン時に常駐**（I/O をログイン直後に先払いする）
- **EmacsClient.app**（Dock 用ランチャー。daemon があると Emacs.app 直起動が
  二重インスタンスになり org-roam.db 等を壊すので、その回避）
- **socket 待ちループ**（最大 60 秒。コールド起動時のインスタンス生成レース回避）

同じコミットで入れた、これとは別問題の対策（こちらは有効なので現存）:

- **lsp のファイルウォッチャから tmp/ coverage/ .bundle/ を除外**
  （rb ファイルを開くたびのコスト。myapp で 44,263 → 4,399 ファイル）
- **java / lean / php / rust モジュールを無効化**（使わない言語の整理）

## 第2幕: daemon 常駐をやめた（現在の構成）

daemon 方式は「起動時間を設定で殴る」ための足場が大きくなりすぎた
（daemon の生存管理 + 二重起動防止の .app + socket 待ちループ）。
費用対効果が悪いと判断し、**起動高速化の努力そのものを諦めて**巻き戻した:

- launchd エージェント・EmacsClient.app・socket 待ちループを **全削除**
- 代わりに `/Applications/Emacs.app` を復活（GUI 起動の導線が必要）
  - `~/Applications` ではなく `/Applications` なのは、`~/Applications` だと
    Spotlight のアプリ索引に載らなかったため（`mdfind` で出てこない）
  - 手動 symlink だと nix 管理外になり、消したとき LaunchServices の登録が
    dangling になって名前解決が壊れた過去がある。今は activation script で毎回張り直す
- `git.nix` の `editor` を `emacsclient` → `emacsclient -t -a emacs` に
  （daemon が無いので、socket が無いときは通常の emacs にフォールバックさせる）

## 第3幕: 「I/O 説」を実測で検証したら、外れていた

第1幕は「1.4GB あるから」という状態量からの推測で、キャッシュを落として測る
対照実験をやっていなかった。改めて `sudo purge` でページキャッシュを捨てて計測:

| 条件 | emacs-init-time | wall |
|---|---|---|
| ターミナル warm | 1.85s | 1.99s |
| ターミナル `sudo purge` 後 | 2.47s | **3.05s** |
| GUI warm | 2.08s | 2.33s |
| GUI `sudo purge` 後 | 3.30s | **3.89s** |
| Dock 経由（LaunchServices+Gatekeeper 込み） | — | **0.66s** |

**ページキャッシュを全部捨てても +1 秒程度**。I/O は 20 秒の説明になっていない。
→ 第1幕の「コールド I/O が支配的」は **誤り**。

調査中に分かった周辺事実:

- straight の 1.1GB は大半が git リポジトリで、起動時には読まれない（サイズと無関係）
- eln キャッシュ 270MB のうち **161MB（1410 ファイル）が死蔵**。
  Emacs 29.4 世代（`29.4-5a308482` / `29.4-642652f6`）で、現在は 30.2。
  Emacs は自分のバージョンの eln しか見ないので起動時間には効かないが、消してよいゴミ。
- Emacs.app は **ad-hoc 署名**（`TeamIdentifier=not set` / `spctl` 不通過）。
  ad-hoc 署名コードは AMFI の検証対象で、**検証結果はブート単位でキャッシュ**される。
  「再起動後の初回だけ遅い」症状とは整合する（未確定の容疑）。

## 検証の落とし穴（重要）

- **ログアウト→ログインでは再現しない。** カーネルは再起動していないので、
  ページキャッシュも AMFI 署名検証キャッシュも前セッションのまま残る。
  `uptime` を見て、本当に reboot 後か確認すること。
- 24 秒が出るのは **reboot 後の初回**。それ以外の状態でいくら測っても最大 3〜4 秒。

## まだ分かっていないこと / 次に調べる筋

**24 秒はまだ一度も再現・計測できていない。** 残る変数は「reboot をまたぐ状態」。
有力な容疑:

1. **AMFI の署名検証**（ad-hoc 署名 = ブート単位キャッシュ。上記参照）

### reboot 後に流す切り分け手順

reboot 直後、**他アプリを開かずターミナルだけ**開いて計測する:

```
docs/emacs-boot-bench.sh  # 設定なし / Doom 1回目 / 2回目 / purge後 を並べて測る
```

- `emacs -Q`（設定なし）でも遅い → 原因は Doom 設定ではなく Emacs バイナリ側（署名検証等）
- 1 回目だけ遅く 2 回目が速い → I/O ではなく初回限定のコスト（AMFI / セキュリティスキャン）
- `sudo purge` 後も 2 回目と同等 → I/O は無関係で確定

同時に `ps -Aro 'pcpu,comm' | head` と `uptime` を撮り、
McAfee/Trellix 等が CPU を食っていないか確認する。
