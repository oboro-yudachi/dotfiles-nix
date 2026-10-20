# Orca（stablyai/orca、コーディングエージェント用デスクトップアプリ）を公式 DMG から入れる。
# nixpkgs の `orca` は GNOME のスクリーンリーダーなので使えない。
# Homebrew にも同名の cask は無い（あるのは plotly の orca）。
# 更新するときは version を上げ、hash は下記で取り直す:
#   nix-prefetch-url https://github.com/stablyai/orca/releases/download/v<version>/orca-macos-arm64.dmg
{ pkgs, ... }:
let
  version = "1.4.230";

  orca = pkgs.stdenvNoCC.mkDerivation {
    pname = "orca";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-macos-arm64.dmg";
      hash = "sha256-+N6fmR+unHJmyTfM81WNj/l9l0hycP1ejzMqc7lWpuQ=";
    };

    # undmg が .dmg の unpack フックを提供する
    nativeBuildInputs = [ pkgs.undmg ];
    sourceRoot = ".";

    # fixup（shebang 書き換え等）を走らせると署名済みバンドルの seal が壊れるので無効化する
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications"
      cp -R *.app "$out/Applications/"

      runHook postInstall
    '';

    meta = {
      description = "Agent development environment for running coding agents in parallel";
      homepage = "https://www.onorca.dev/";
      license = pkgs.lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  # home-manager の darwin.copyApps（デフォルトで有効）で ~/Applications/Home Manager Apps に配置される
  home.packages = [ orca ];
}
