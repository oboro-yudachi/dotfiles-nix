{ config, pkgs, lib, ... }:

{
  imports = [
    ./mise.nix
  ];

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
    rustup
  ];

  home.file = {
    ".gitconfig".source = ./git/.gitconfig;
    ".doom.d/init.el".source     = ./doom.d/init.el;
    ".doom.d/packages.el".source = ./doom.d/packages.el;
    ".doom.d/config.el".source   = ./doom.d/config.el;
  };

  home.sessionVariables = {
  };

  programs.home-manager.enable = true;
}
