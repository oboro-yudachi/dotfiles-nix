# CLI ツールのうち、programs.X.enable の対象でないものを home.packages で入れる。
{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    # Nix
    nixfmt

    # Build / system libs
    cmake
    coreutils
    libtool
    libyaml
    shellcheck
    zstd

    # CLI tools（gh は git.nix の programs.gh で管理）
    jq
    difftastic
    neovim
    screen
    tree-sitter
    _7zz

    # Networking
    cloudflared

    # Search
    fd
    ripgrep

    # TypeScript。Doom の :lang javascript +lsp が typescript-language-server を使う。
    typescript
    typescript-language-server

    # Languages
    # 言語ランタイムは当面 nix で直接管理する（mise には移行しない方針。これから育てていく）。
    agda
    bun
    nodejs_24
    # +jupyter（emacs-jupyter）用に jupyter/ipykernel 込みで入れる
    (python314.withPackages (ps: with ps; [ jupyter ipykernel ]))
    ruby_4_0
    uv
  ];

  # ccusage は nixpkgs 未対応のため npm グローバルインストールで管理
  home.activation.installCcusage = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/ccusage" ]; then
      ${pkgs.nodejs_24}/bin/npm install -g ccusage --prefix "$HOME/.local"
    fi
  '';

  # Notion CLI (ntn) も nixpkgs / homebrew 未対応のため npm グローバルインストールで管理
  # https://developers.notion.com/cli/get-started/installation
  # ntn の postinstall スクリプト（install.cjs）が `sh -c "node ..."` で node を
  # PATH 経由で探すため、npm 本体をフルパス指定するだけでは足りず PATH にも
  # nodejs_24/bin を通しておく必要がある。
  home.activation.installNtn = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/ntn" ]; then
      PATH="${pkgs.nodejs_24}/bin:$PATH" ${pkgs.nodejs_24}/bin/npm install -g ntn --prefix "$HOME/.local"
    fi
  '';
}
