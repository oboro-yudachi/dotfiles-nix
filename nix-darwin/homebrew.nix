{
  nix-homebrew,
  ...
}:
{
  nix-homebrew = {
    enable = true;
    user = "taguchishoh";
    enableRosetta = false;
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    user = "taguchishoh";
    onActivation.cleanup = "zap";

    taps = [
      "d12frosted/emacs-plus"
    ];

    brews = [
      "agda"
      "cmake"
      "coreutils"
      "d12frosted/emacs-plus/emacs-plus@30"
      "jpeg"
      "libtool"
      "libvterm"
      "libyaml"
      "markdown"
      "mise"
      "mo"
      "mysql"
      "rustup"
      "zstd"
    ];

    casks = [
      "font-juliamono"
      "font-rambla"
    ];
  };
}
