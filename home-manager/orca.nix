# Orca（stablyai/orca、コーディングエージェント用デスクトップアプリ）。
# nixpkgs の `orca` は GNOME のスクリーンリーダー、Homebrew の `orca` は plotly のもので別物。
{ pkgs, lib, ... }:
let
  # 引数のディレクトリ（既定 /Applications）に Orca.app が無いときだけ、最新の公式 DMG から入れる。
  # 失敗してもアクティベーション全体は止めず、警告だけ出して 0 で抜ける。
  installOrcaApp = pkgs.writeShellScript "install-orca-app" ''
    set -u
    dest="''${1:-/Applications}"
    app="$dest/Orca.app"
    url="https://github.com/stablyai/orca/releases/latest/download/orca-macos-arm64.dmg"

    warn() { echo "warning: installOrca: $*" >&2; }

    [ -e "$app" ] && exit 0

    tmp=$(mktemp -d "''${TMPDIR:-/tmp}/install-orca.XXXXXX") || {
      warn "一時ディレクトリを作れなかった。Orca のインストールを飛ばす"
      exit 0
    }
    mnt="$tmp/mnt"
    attached=0
    cleanup() {
      if [ "$attached" = 1 ]; then
        /usr/bin/hdiutil detach -quiet "$mnt" || /usr/bin/hdiutil detach -quiet -force "$mnt"
      fi
      rm -rf "$tmp"
    }
    trap cleanup EXIT

    echo "Orca.app が $dest に無いので最新の公式 DMG から入れる"
    if ! /usr/bin/curl -fsSL --retry 2 -o "$tmp/orca.dmg" "$url"; then
      warn "DMG のダウンロードに失敗した（''${url}）。Orca のインストールを飛ばす"
      exit 0
    fi

    mkdir "$mnt"
    if ! /usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -quiet -mountpoint "$mnt" "$tmp/orca.dmg"; then
      warn "DMG をマウントできなかった。Orca のインストールを飛ばす"
      exit 0
    fi
    attached=1

    if [ ! -d "$mnt/Orca.app" ]; then
      warn "DMG に Orca.app が無い。Orca のインストールを飛ばす"
      exit 0
    fi

    if ! /usr/bin/ditto "$mnt/Orca.app" "$app"; then
      warn "$app へのコピーに失敗した。途中までのコピーを消す"
      rm -rf "$app"
      exit 0
    fi

    if ! /usr/bin/codesign --verify --deep --strict "$app"; then
      warn "$app の署名検証に失敗したので消す"
      rm -rf "$app"
      exit 0
    fi

    echo "Orca.app を $dest に入れた"
  '';
in
{
  # Nix はインストール済みかどうかだけを保証し、バージョンは固定しない。
  # Orca はアプリ内で自分自身を上書き更新する。以前はパッケージとして固定版を
  # home.packages に入れていたが、copyApps（rsync --delete）が switch のたびに
  # ~/Applications/Home Manager Apps の Orca.app を固定版で上書きし、自動更新を巻き戻していた。
  home.activation.installOrca = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${installOrcaApp} /Applications || echo "warning: installOrca が失敗したが続行する" >&2
  '';
}
