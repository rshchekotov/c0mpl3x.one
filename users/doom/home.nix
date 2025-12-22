{ config, pkgs, ... }:
{
  home.username = "doom";
  home.homeDirectory = "/home/doom";
  home.stateVersion = "25.11";
  home.enableNixpkgsReleaseCheck = false;
  home.packages = [];
  home.file = {};
  home.sessionVariables = {};
  programs.home-manager.enable = true;
}