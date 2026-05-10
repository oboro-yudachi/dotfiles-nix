{
  self,
  ...
}:
{
  users.users."taguchishoh".home = "/Users/taguchishoh";

  imports = [
    ./home_manager.nix
    ./homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.configurationRevision = self.rev or self.dirtyRev or null;

  security.pam.services.sudo_local.touchIdAuth = true;

  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  programs.zsh.enable = true;

  system.activationScripts.postActivation.text = ''
    sudo -u taguchishoh ln -sf /opt/homebrew/opt/emacs-plus@30/Emacs.app /Users/taguchishoh/Applications/Emacs.app
  '';
}
