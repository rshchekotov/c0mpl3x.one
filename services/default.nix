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

        # Expose 80/443/8080 on the host
        ports = [
          "80:80"
          "443:443"
          "8080:8080"
        ];


        volumes = [
          "${./traefik/dynamic}:/etc/traefik/dynamic:ro"
        ];

        # Command flags from the Traefik docs example
        exec = lib.concatStringsSep " " [
          "traefik"
          "--api.insecure=false"
          "--api.dashboard=true"
          "--providers.docker=false"
          "--providers.file.directory=/etc/traefik/dynamic"
          "--entryPoints.web.address=:8080"
          "--entryPoints.websecure.address=:8443"
          "--entryPoints.websecure.http.tls=true"
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
      };
    };
  };
}
