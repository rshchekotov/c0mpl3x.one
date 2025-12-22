{
  pkgs,
  ...
}:
{
  imports = [
    ./bash.nix
    ./git.nix
    ./helix.nix
    ./less.nix
    ./nushell.nix
  ];
}