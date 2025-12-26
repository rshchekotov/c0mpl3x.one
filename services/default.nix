{ config, pkgs, lib, ... }:
let
  domain = "c0mpl3x.one";
  headscaleDir = "${config.xdg.configHome}/headscale";
in {
  home.activation.createHeadscaleDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${headscaleDir}/config ${headscaleDir}/data
  '';

  services.podman = {
    enable = true;

    containers = {
      traefik = {
        image = "traefik:v3.4";

        extraConfig.Service = {
          Restart = "on-failure";
          RestartSec = "5";
        };

        # For now: only HTTP, on 8080
        ports = [ "9090:9090" ];

        volumes = [
          "${./traefik/dynamic}:/etc/traefik/dynamic:ro"
        ];

        # NO volumes, NO docker provider, NO file provider yet
        exec = lib.concatStringsSep " " [
          "traefik"
          "--api.insecure=true"
          "--providers.file.directory=/etc/traefik/dynamic"
          "--providers.file.watch=true"
          "--entryPoints.web.address=:9090" # Matches container-side port
          "--log.level=DEBUG"
        ];
      };

      whoami = {
        image = "traefik/whoami";
        extraConfig.Service = {
          Restart = "on-failure";
          RestartSec = "5";
        };
        ports = [ "8081:80" ];
      };

      headscale = {
        image = "headscale/headscale:latest";
        extraConfig.Service = {
          Restart = "on-failure";
          RestartSec = "5";
        };
        
        # Expose Headscale port to host (e.g. 8080 on host -> 8080 in container)
        # Traefik will proxy to localhost:8080
        ports = [ "8080:8080" ];

        volumes = [
          "${headscaleDir}/config:/etc/headscale"
          "${headscaleDir}/data:/var/lib/headscale"
        ];

        # The default command for the headscale container is usually "headscale serve"
        # but sometimes you need to be explicit.
        exec = "headscale serve"; 
      };
    };
  };
}
