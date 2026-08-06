{
  description = "Mac (shounoMacBook-Air) の nix-darwin + home-manager 構成";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
    }:
    let
      # ホスト固有の値はここ1箇所に集約する。
      # 各ファイルに同じ値をハードコードすると多ホスト対応ができなくなるので、
      # 参照は必ず specialArgs 経由にする。
      username = "taguchishoh";
      hostname = "shounoMacBook-Air"; # scutil --get LocalHostName
      system = "aarch64-darwin";
    in
    {
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit self inputs username hostname; };
        modules = [
          ./nix-darwin/configuration.nix
        ];
      };

      # `nix fmt` 用
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
    };
}
