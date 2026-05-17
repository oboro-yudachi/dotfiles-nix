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
  };

  home.sessionVariables = {
  };

  programs.home-manager.enable = true;
}
