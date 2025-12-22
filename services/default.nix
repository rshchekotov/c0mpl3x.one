{ config, pkgs, lib, ... }:
let
  domain = "c0mpl3x.one";
in {
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/home/${config.home.username}/.config/sops/age/keys.txt";

    secrets.domain = {
      path = "${config.sops.defaultSymlinkPath}/domain";
    };
  };

  services.podman = {
    enable = true;

    containers = {
      traefik = {
        image = "traefik:v3.4";

        extraConfig = {
          Service = {
            Restart = "on-failure";
            RestartSec = "5";
          };
        };

        # For now: only HTTP, on 8080
        ports = [ "9090:9090" ];

        # NO volumes, NO docker provider, NO file provider yet
        exec = lib.concatStringsSep " " [
          "traefik"
          "--api.insecure=true"             # expose dashboard on :8080/dashboard/
          "--entryPoints.web.address=:9090"
          "--log.level=DEBUG"
        ];
      };

      whoami = {
        image = "traefik/whoami";
        extraConfig = {
          Service = {
            Restart = "on-failure";
            RestartSec = "5";
          };
        };
        ports = [ "8081:80" ];
      };
    };
  };
}
