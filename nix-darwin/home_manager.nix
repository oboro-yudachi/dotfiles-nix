# home-manager を nix-darwin モジュールとして配線するだけのファイル。
# 実際のユーザー設定は ../home-manager/home.nix 側に書く。
{
  inputs,
  username,
  ...
}:
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit username; };
    users.${username} = import ../home-manager/home.nix;
  };
}
