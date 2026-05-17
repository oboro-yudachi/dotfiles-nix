{ pkgs, lib, ... }:

{
  home.activation.miseInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.mise}/bin/mise install --quiet
    ${pkgs.mise}/bin/mise prune --yes
  '';

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      settings = {
        idiomatic_version_file_enable_tools = [ "node" "ruby" ];
      };
      tools = {
        bun = "1.3.11";
        node = "24.14.1";
        ruby = "4.0.0";
        python = "3.14.4";
        mysql = "8.0";
      };
    };
  };
}
