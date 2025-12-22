{ config, pkgs, ... }:
let
  domain = builtins.trim (builtins.readFile config.sops.secrets.domain.path);
  podmanSocket = "/run/user/1000/podman/podman.sock";
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

    # Create a "proxy" bridge network similar to the docker-compose example
    networks.proxy.driver = "bridge";

    containers = {
      traefik = {
        image = "traefik:v3.4";

        extraConfig = {
          Service = {
            Restart = "on-failure";
            RestartSec = "5";
          };
        };

        # Attach to the proxy network
        network = [ "proxy" ];

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
          "${podmanSocket}:/var/run/docker.sock:ro"
          # optional: bind dynamic config / certs similar to the compose example
          # "${config.home.homeDirectory}/traefik/certs:/certs:ro"
          # "${config.home.homeDirectory}/traefik/dynamic:/etc/traefik/dynamic:ro"
        ];

        # Command flags from the Traefik docs example
        exec = [
          "traefik"
          "--api.insecure=false"
          "--api.dashboard=true"
          "--providers.docker=true"
          "--providers.docker.exposedbydefault=false"
          "--providers.docker.network=proxy"
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
        network = [ "proxy" ];

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
