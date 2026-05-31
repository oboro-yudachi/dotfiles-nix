{ config, pkgs, lib, ... }:

{
  home.username = "taguchishoh";
  home.homeDirectory = "/Users/taguchishoh";

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    nixfmt
    git
    fd
    ripgrep
    gh
    shellcheck
    cmake
    coreutils
    zstd
    libtool
    libyaml
    ruby_4_0
    python314
    bun
    nodejs_24
  ];

  # ccusage は nixpkgs 未対応のため npm グローバルインストールで管理
  # ~/.local/bin は zsh initContent で PATH に追加済み
  home.activation.installCcusage = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/ccusage" ]; then
      ${pkgs.nodejs_24}/bin/npm install -g ccusage --prefix "$HOME/.local"
    fi
  '';

  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
    ".doom.d/init.el".source     = ./doom.d/init.el;
    ".doom.d/packages.el".source = ./doom.d/packages.el;
    ".doom.d/config.el".source   = ./doom.d/config.el;
  };

  home.sessionVariables = {
  };

  xdg.configFile = {
    "ghostty/config".source = ./ghostty/config;
  };

  programs.zsh = {
    enable = true;
    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.emacs.d/bin:$PATH"

      EMACS_PLUS_BIN="/opt/homebrew/opt/emacs-plus@30/bin/emacs"
      EMACS_PLUS_APP="/opt/homebrew/opt/emacs-plus@30/Emacs.app"

      function use-emacs-plus() {
        export EMACS="$EMACS_PLUS_BIN"
        { [ -e /Applications/Emacs.app ] || [ -L /Applications/Emacs.app ]; } && rm /Applications/Emacs.app
        ln -sf "$EMACS_PLUS_APP" /Applications/Emacs.app
        echo "Switched to emacs-plus: $($EMACS --version | head -1)"
        echo "Running doom sync..."
        doom sync
      }
    '';
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.home-manager.enable = true;
}
