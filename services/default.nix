{ config, pkgs, lib, ... }:
let
  domain = "c0mpl3x.one";
  headscaleDir = "${config.xdg.configHome}/headscale";
  acmeDir = "${config.xdg.configHome}/traefik/acme";
in {
  home.activation.createDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${headscaleDir}/config ${headscaleDir}/data
    mkdir -p ${acmeDir}
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
        ports = [
          "80:80"
          "443:443"
          "9090:443"
        ];

        volumes = [
          "${./traefik/dynamic}:/etc/traefik/dynamic:ro"
          "${acmeDir}:/etc/traefik/acme"
        ];

        exec = lib.concatStringsSep " " [
          "traefik"
          "--api.insecure=true"
          "--providers.file.directory=/etc/traefik/dynamic"
          "--providers.file.watch=true"
          
          # --- EntryPoints ---
          "--entryPoints.web.address=:80"
          # Global Redirect HTTP -> HTTPS
          "--entryPoints.web.http.redirections.entryPoint.to=websecure"
          "--entryPoints.web.http.redirections.entryPoint.scheme=https"
          
          "--entryPoints.websecure.address=:443"
          "--entryPoints.headscale_secure.address=:9090"
          
          # --- Let's Encrypt (Resolver) ---
          "--certificatesResolvers.myresolver.acme.email=webmaster@c0mpl3x.one"
          "--certificatesResolvers.myresolver.acme.storage=/etc/traefik/acme/acme.json"
          "--certificatesResolvers.myresolver.acme.httpChallenge.entryPoint=web"
          
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
        ports = [
          "8080:8080"
          "9091:9090"
        ];

        volumes = [
          "${headscaleDir}/config:/etc/headscale"
          "${headscaleDir}/data:/var/lib/headscale"
        ];

        # The default command for the headscale container is usually "headscale serve"
        # but sometimes you need to be explicit.
        exec = "serve"; 
      };
    };
  };
}
