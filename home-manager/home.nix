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

      # CLI tools
      gh

      # Search
      fd
      ripgrep

      # Languages
      agda
      bun
      nodejs_24
      python314
      ruby_4_0
      uv
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

    # delta: git diff のビジュアライザ
    delta = {
      enable = true;
      enableGitIntegration = true;
    };

    # gh: home-manager に config 管理させず binary のみ使う
    # （既存の ~/.config/gh/config.yml と競合するため packages で管理）

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    lazygit.enable = true;

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = "$username$directory$git_branch$character";
        username = {
          show_always = true;
          format = "[$user]($style) ";
        };
        directory = {
          truncate_to_repo = false;
        };
        nodejs = {
          disabled = true;
        };
        git_status = {
          disabled = true;
        };
      };
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
    };

    bat.enable = true;

    eza = {
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
