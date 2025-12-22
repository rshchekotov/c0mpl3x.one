{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./home.nix
    ./modules/programs
  ];
}