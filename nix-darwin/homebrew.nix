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
      # macOS 向け独自パッチ（ネイティブフルスクリーン等）が含まれる特殊 tap のため nixpkgs に移行不可
      "d12frosted/emacs-plus/emacs-plus@30"
      # 依存関係には現れないが Doom Emacs の起動に必要
      "jpeg"
      # nixpkgs の libvterm は Linux 専用（meta.platforms に aarch64-darwin が含まれない）
      "libvterm"
      # markdown viewer系
      "markdown"
      "mo"
    ];

    casks = [
      "font-juliamono"
      "font-rambla"
    ];
  };
}
