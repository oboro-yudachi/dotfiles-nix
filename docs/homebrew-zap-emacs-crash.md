# flake.lock 更新後に Doom Emacs が起動しなくなった件

- 発生日: 2026-08-22
- 環境: MacBook（macOS 27.0 beta / 26A5406e、arm64）
- 関連ファイル: `nix-darwin/homebrew.nix`, `home-manager/emacs.nix`, `flake.lock`
- ステータス: **復旧済み**。`nix-darwin/homebrew.nix` に再発防止策も追加済み

## 症状

`flake.lock` を更新して `darwin-rebuild switch` を実行した後、Emacs.app が
起動直後に落ちるようになった。macOS のクラッシュレポートには以下が出ていた:

```
Termination Reason:  Namespace DYLD, Code 1, Library missing
Library not loaded: /opt/homebrew/*/libgif.dylib
Referenced from: .../Emacs.app/Contents/MacOS/Emacs
Reason: tried: '/opt/homebrew/*/libgif.dylib' (no such file), ...
```

## 原因

`git diff` で見ると、この switch 前後で `flake.lock` の `brew-src`（nix-homebrew が
使う Homebrew 本体）が **`5.1.11` → `6.0.16` というメジャーバージョン更新**を
またいでいた。

`nix-darwin/homebrew.nix` は `onActivation.cleanup = "zap"` で運用しており、
「`brews`/`casks`/`taps` に宣言していない formula は容赦なく削除する」方針。
本来、宣言した formula（今回なら `emacs-plus@30`）の *依存関係* は自動的に
保護される（`brew bundle cleanup` は依存グラフを辿って必要な formula を
残す）はずだが、今回はこの依存解決が壊れ、`emacs-plus@30` が実際に必要として
いる transitive dependency が **十数個まとめて Cellar ごと消えていた**:

```
giflib, webp, librsvg, gdk-pixbuf, zlib, libgccjit, tree-sitter@0.25,
gcc, mpfr, libmpc, isl, icu4c@78, pango, libthai, libdatrie, fribidi,
harfbuzz, graphite2
```

クラッシュログの `libgif.dylib` はこのうちの一つに過ぎない。`otool -L` で
`Emacs.app` 本体を見ると同じパス配下に上記すべてへの動的リンクがあり、
`giflib` だけ直しても次は `libgccjit` や `libtree-sitter` で同じ現象が
再発する状態だった。

`home-manager/emacs.nix` のコメントにある「`jpeg` を `brews` に明示追加した」
経緯（＝ `cleanup="zap"` は宣言に無い依存を容赦なく削除するので、暗黙の依存に
頼ると壊れる）と同種の問題が、Homebrew 本体のメジャーアップデートを機に
一気に広範囲へ波及した形。

なお `emacs-plus@30` 自体（Cellar の `30.2`）は消えておらず再ビルドもされて
いなかった。壊れたのはあくまで **依存ライブラリ側**。

## 切り分けに使ったコマンド

```sh
# クラッシュ時に読みに行っている dylib の実体を確認
otool -L /opt/homebrew/opt/emacs-plus@30/Emacs.app/Contents/MacOS/Emacs

# 各依存の opt シンボリックリンク／Cellar の有無を機械的にチェック
for p in giflib webp librsvg gdk-pixbuf zlib libgccjit tree-sitter@0.25 ...; do
  [ -e "/opt/homebrew/opt/$p" ] && echo "OK $p" || echo "MISS $p"
done

# インストール時点で何に依存していたか（INSTALL_RECEIPT.json）と比較
cat /opt/homebrew/Cellar/emacs-plus@30/*/INSTALL_RECEIPT.json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(x["full_name"]) for x in d["runtime_dependencies"]]'
```

## 復旧手順

1. **Command Line Tools の更新が必要だった**。macOS 27 betaは bottle（ビルド済み
   バイナリ）が提供されておらず `emacs-plus@30`/`gcc` はソースビルドにフォール
   バックするが、既存の CLT (26.4.0) では新しい Xcode 相当のビルドができず
   `Your Command Line Tools are too outdated.` で失敗した。
   ```sh
   softwareupdate --list
   sudo softwareupdate --install "Command Line Tools for Xcode 27.0 beta 5-27.0"
   ```
2. **`emacs-plus@30` を reinstall して依存を丸ごと引き直す**。
   ```sh
   brew reinstall d12frosted/emacs-plus/emacs-plus@30
   ```
   - 途中、`gnu-sed` や `coreutils` など個別の formula で
     `Error: No such file or directory @ rb_sysopen - .../downloads/<hash>--<name>.tar.gz`
     という、キャッシュにファイルが無いと言われて pour が落ちる現象が複数回発生した
     （ファイル自体は存在することもあり、原因未特定。おそらく brew 6.0.16 の
     一括インストール時のダウンロード/pour の競合・タイミングのバグ）。
     `brew install <その formula単体>` を個別に実行すると通常どおり成功したので、
     失敗するたびに該当 formula を単体インストールしてキャッシュを温めてから
     `brew reinstall d12frosted/emacs-plus/emacs-plus@30` をやり直す、を繰り返して
     最終的に完走させた。
3. `otool -L` で全依存パスの存在を再確認し、`--batch` 起動で
   `emacs-version` が取れること、`early-init.el` が読み込めることを確認した。

## 再発防止

`nix-darwin/homebrew.nix` の `brews` に、今回 zap で消えた transitive dependency
（`brew deps -n d12frosted/emacs-plus/emacs-plus@30` の出力で裏取り）を
明示的に追加した。これにより `cleanup="zap"` の依存解決が今回のように
壊れても、これらの formula は「宣言済み」として直接保護される。

ただし **これは対症療法**であり、根本原因（brew 6.0.16 系での依存解決の
不具合、あるいは nix-homebrew 側の何らかの非互換）そのものは未特定のまま。
今後また Homebrew 本体のメジャーバージョンが上がる `flake update` を行う際は、
`darwin-rebuild switch` 適用前に一度 `brew bundle cleanup --dry-run`
相当（Nix生成 Brewfile に対して）で削除対象を確認する、または
`brew deps --tree d12frosted/emacs-plus/emacs-plus@30` と実機の Cellar を
突き合わせてから switch する運用が望ましい。
