{ config, pkgs, lib, ... }:

{
  home = {
    username = "taguchishoh";
    homeDirectory = "/Users/taguchishoh";
    stateVersion = "25.11";

    packages = with pkgs; [
      # Nix
      nixfmt

      # Build / system libs
      cmake
      coreutils
      libtool
      libyaml
      shellcheck
      zstd

      # Search
      fd
      ripgrep

      # Languages
      agda
      bun
      nodejs_24
      python314
      ruby_4_0
    ];

    # ccusage は nixpkgs 未対応のため npm グローバルインストールで管理
    activation.installCcusage = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.local/bin/ccusage" ]; then
        ${pkgs.nodejs_24}/bin/npm install -g ccusage --prefix "$HOME/.local"
      fi
    '';

    file = {
      ".gitconfig".source          = ./git/.gitconfig;
      ".doom.d/init.el".source     = ./doom.d/init.el;
      ".doom.d/packages.el".source = ./doom.d/packages.el;
      ".doom.d/config.el".source   = ./doom.d/config.el;
    };

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.emacs.d/bin"
    ];
  };

  xdg.configFile = {
    "ghostty/config".source = ./ghostty/config;
  };

  programs = {
    # git インストールのみ; 設定は home.file の .gitconfig で管理
    git.enable = true;
    gh.enable = true;

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    zsh = {
      enable = true;
      initContent = ''
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

    home-manager.enable = true;
  };
}
