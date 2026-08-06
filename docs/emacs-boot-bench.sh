#!/bin/bash
# Doom Emacs の起動が reboot 後だけ遅い件（docs/emacs-startup.md）の切り分け用。
#
# ★reboot 直後に、他のアプリを一切開かず、ターミナルだけ開いて実行すること★
# ログアウト→ログインでは再現しない（カーネルが再起動していないため）。
set -u
OUT=/tmp/emacs-boot-bench.txt
E=/opt/homebrew/bin/emacs
now() { python3 -c 'import time;print(time.time())'; }
run() { # $1=ラベル  $2...=emacs 引数
  local label="$1"
  shift
  local s e
  s=$(now)
  script -q /dev/null "$E" "$@" --eval '(kill-emacs)' >/dev/null 2>&1
  e=$(now)
  printf '%-28s %s\n' "$label" "$(python3 -c "print(f'{$e-$s:.2f}s')")" | tee -a "$OUT"
}

: >"$OUT"
echo "=== 起動後 $(uptime | sed 's/.*up //;s/,.*//') 経過時点 ===" | tee -a "$OUT"

# 1) 設定なし。Emacs 本体 + 同梱 eln のみ。
#    ここが遅ければ原因は Doom 設定ではなく Emacs バイナリ側（署名検証など）。
run "1. emacs -Q (設定なし)" -Q -nw

# 2) Doom フル。1 との差が Doom の分。
run "2. Doom フル (1回目)" -nw

# 3) もう一度 Doom フル。2 との差が「ブート単位で一度だけ払うコスト」。
#    2 が遅く 3 が速ければ、I/O ではなく初回限定の何か（AMFI の署名検証等）。
run "3. Doom フル (2回目)" -nw

# 4) ページキャッシュだけ捨ててもう一度。3 とほぼ同じなら I/O は原因ではない。
echo "--- sudo purge ---" | tee -a "$OUT"
sudo purge
run "4. Doom フル (purge後)" -nw

# 同時に、セキュリティエージェントが CPU を食っていないかも見る。
echo "--- CPU 上位（McAfee/Trellix 等が居るか） ---" | tee -a "$OUT"
ps -Aro 'pcpu,comm' | head -10 | tee -a "$OUT"

echo
echo "結果は $OUT にも保存した。"
