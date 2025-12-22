{
  home.shell.enableNushellIntegration = true;

  programs.nushell = {
    enable = true;
    configFile.text = ''
      alias hx = helix

      def hms [] {
        cd ~/devops
        nix build .#homeConfigurations."doom".activationPackage
        ./result/activate
      }
    '';
    environmentVariables = {
      TERM = "xterm-256color";
    };
  };
}