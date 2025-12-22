{
  pkgs,
  ...
}:
{
  imports = [
    ./bash.nix
    ./helix.nix
    ./nushell.nix
  ];
}