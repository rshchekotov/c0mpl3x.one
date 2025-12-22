{ config, pkgs, lib, ... }:
let
  podmanSocket = "/run/user/1000/podman/podman.sock";
  podmanApiPort = "12345";
  domain = "c0mpl3x.one";
in {
  systemd.user.services.podman-api = {
    Unit = {
      Description = "Rootless Podman API service";
      After = [ "default.target" ];
    };

    Service = {
      # Keep the service running
      Restart = "always";
      RestartSec = 5;

      # Podman API server; --time=0 means never auto-exit
      ExecStart = ''
        ${pkgs.podman}/bin/podman system service --time=0 tcp:127.0.0.1:${podmanApiPort}
      '';
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

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

        # Mount the Podman socket so Traefik can see other containers
        # For rootless Podman this is usually under $XDG_RUNTIME_DIR
        volumes = [
          # adjust path if your podman.sock is elsewhere
          # "${podmanSocket}:/var/run/docker.sock:ro"
          # optional: bind dynamic config / certs similar to the compose example
          # "${config.home.homeDirectory}/traefik/certs:/certs:ro"
          # "${config.home.homeDirectory}/traefik/dynamic:/etc/traefik/dynamic:ro"
        ];

        # Command flags from the Traefik docs example
        exec = lib.concatStringsSep " " [
          "traefik"
          "--api.insecure=false"
          "--api.dashboard=true"
          "--providers.docker=true"
          "--providers.docker.exposedbydefault=false"
          "--providers.docker.network=podman"
          "--providers.docker.endpoint=tcp://127.0.0.1:${podmanApiPort}"
          "--providers.file.directory=/etc/traefik/dynamic"
          "--entryPoints.web.address=:80"
          "--entryPoints.websecure.address=:443"
          "--entryPoints.websecure.http.tls=true"
        ];

        # Labels to expose the Traefik dashboard itself via HTTPS
        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.dashboard.rule" = "Host(`dashboard.${domain}`)";
          "traefik.http.routers.dashboard.entrypoints" = "websecure";
          "traefik.http.routers.dashboard.service" = "api@internal";
          "traefik.http.routers.dashboard.tls" = "true";
        };
      };

      whoami = {
        image = "traefik/whoami";
        extraConfig = {
          Service = {
            Restart = "on-failure";
            RestartSec = "5";
          };
        };

        labels = {
          "traefik.enable" = "true";
          "traefik.http.routers.whoami.rule" = "Host(`whoami.${domain}`)";
          "traefik.http.routers.whoami.entrypoints" = "websecure";
          "traefik.http.routers.whoami.tls" = "true";
        };
      };
    };
  };
}
