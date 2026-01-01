terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }

    # Use random for secret generation
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "docker" {
  host = "unix:///run/podman/podman.sock"
}

# --- 0. Secrets & Network ---
resource "random_password" "pg_password" {
  length  = 16
  special = false
}

resource "random_password" "authentik_secret" {
  length  = 50
  special = false
}

resource "docker_network" "private_net" {
  name   = "doom-internal"
  driver = "bridge"

  lifecycle {
    ignore_changes = [ ipam_options ]
  }
}

# --- 0.5. Volumes ---
resource "docker_volume" "pg_data" {
  name = "authentik_pg_data"
}

resource "docker_volume" "redis_data" {
  name = "authentik_redis_data"
}

resource "docker_volume" "headscale_data" {
  name = "headscale_data"
}

resource "docker_volume" "authentik_media" {
  name = "authentik_media"
}

# --- 1. Database (Postgres) & Redis for Authentik ---
resource "docker_image" "postgres_img" {
  name = "docker.io/library/postgres:18-alpine"
  keep_locally = true
}

resource "docker_container" "postgres" {
  name    = "authentik_db"
  image   = docker_image.postgres_img.image_id
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.private_net.name
  }
  
  env = [
    "POSTGRES_PASSWORD=${random_password.pg_password.result}",
    "POSTGRES_USER=authentik",
    "POSTGRES_DB=authentik"
  ]

  volumes {
    volume_name    = docker_volume.pg_data.name
    container_path = "/var/lib/postgresql/data"
  }

  lifecycle {
    ignore_changes = [ pid_mode, ulimit ]
  }
}

resource "docker_image" "valkey_img" {
  name = "docker.io/valkey/valkey:9-alpine"
  keep_locally = true
}

resource "docker_container" "redis" {
  name    = "authentik_redis"
  image   = docker_image.valkey_img.image_id
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.private_net.name
  }
  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }

  lifecycle {
    ignore_changes = [ pid_mode, ulimit ]
  }
}

# --- 2. Authentik Server & Worker ---
resource "docker_image" "authentik_img" {
  name = "ghcr.io/goauthentik/server:2025.12.0-rc2"
  keep_locally = true
}

resource "docker_container" "authentik_server" {
  name    = "authentik_server"
  image   = docker_image.authentik_img.image_id
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.private_net.name
  }

  # Common Env Vars
  env = [
    "AUTHENTIK_REDIS__HOST=authentik_redis",
    "AUTHENTIK_POSTGRESQL__HOST=authentik_db",
    "AUTHENTIK_POSTGRESQL__USER=authentik",
    "AUTHENTIK_POSTGRESQL__NAME=authentik",
    "AUTHENTIK_POSTGRESQL__PASSWORD=${random_password.pg_password.result}",
    "AUTHENTIK_SECRET_KEY=${random_password.authentik_secret.result}",
    "AUTHENTIK_PORT=9000",
  ]
  
  # Traefik Labels (Expose Authentik Dashboard)
  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.authentik.rule"
    value = "Host(`auth.c0mpl3x.one`)"
  }
  labels {
    label = "traefik.http.routers.authentik.entrypoints"
    value = "websecure"
  }
  labels {
    label = "traefik.http.routers.authentik.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.authentik.tls.certresolver"
    value = "myresolver"
  }
  labels {
    label = "traefik.http.services.authentik.loadbalancer.server.port"
    value = "9000"
  }

  command = ["server"]
  
  # Mounts (for config/templates/media)
  volumes {
    volume_name      = docker_volume.authentik_media.name
    container_path = "/media"
  }

  lifecycle {
    ignore_changes = [ pid_mode, ulimit ]
  }
}

resource "docker_container" "authentik_worker" {
  name    = "authentik_worker"
  image   = docker_image.authentik_img.image_id
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.private_net.name
  }

  # SAME ENV VARS AS SERVER
  env = [
    "AUTHENTIK_REDIS__HOST=authentik_redis",
    "AUTHENTIK_POSTGRESQL__HOST=authentik_db",
    "AUTHENTIK_POSTGRESQL__USER=authentik",
    "AUTHENTIK_POSTGRESQL__NAME=authentik",
    "AUTHENTIK_POSTGRESQL__PASSWORD=${random_password.pg_password.result}",
    "AUTHENTIK_SECRET_KEY=${random_password.authentik_secret.result}",
  ]
  
  # Worker needs access to Docker socket if you use Outposts (optional but common)
  volumes {
    host_path      = "/run/podman/podman.sock"
    container_path = "/var/run/docker.sock"
  }

  volumes {
    volume_name      = docker_volume.authentik_media.name
    container_path = "/media"
  }

  command = ["worker"]

  lifecycle {
    ignore_changes = [ pid_mode, ulimit ]
  }
}

# --- 3. Headscale (with OIDC Config) ---
resource "docker_image" "headscale_img" {
  name = "docker.io/headscale/headscale:latest"
  keep_locally = true
}

resource "docker_container" "headscale" {
  name    = "headscale"
  image   = docker_image.headscale_img.image_id
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.private_net.name
  }

  volumes {
    container_path = "/etc/headscale"
    host_path      = "/opt/infra/headscale/config"
  }

  volumes {
    volume_name    = docker_volume.headscale_data.name
    container_path = "/var/lib/headscale"
  }

  command = ["serve"]

  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.headscale.rule"
    value = "Host(`vpn.c0mpl3x.one`)"
  }
  labels {
    label = "traefik.http.routers.headscale.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.headscale.tls.certresolver"
    value = "myresolver"
  }
  labels {
    label = "traefik.http.services.headscale.loadbalancer.server.port"
    value = "8080"
  }
  # Note: Headscale doesn't need Traefik middleware for Auth,
  # because Headscale does the Auth internally via OIDC.
  lifecycle {
    ignore_changes = [ pid_mode, ulimit ]
  }
}

# --- 4. Traefik (The Gateway) ---
resource "docker_image" "traefik" {
  name = "docker.io/library/traefik:v3.0"  # Explicit registry
  keep_locally = true
}

resource "docker_container" "traefik" {
  name    = "traefik"
  image   = docker_image.traefik.image_id
  restart = "unless-stopped"
  networks_advanced {
    name = docker_network.private_net.name
  }

  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }

  volumes {
    host_path      = "/run/podman/podman.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  volumes {
    host_path      = "/opt/infra/traefik/acme"
    container_path = "/etc/traefik/acme"
  }
  
  # Basic Command (assuming you want Let's Encrypt later)
  command = [
    # Log Stuff
    "--log.level=DEBUG",
    "--accesslog=true",
    # General Stuff
    "--api.insecure=false",
    "--providers.docker=true",
    "--providers.docker.exposedbydefault=false",
    "--entrypoints.web.address=:80",
    "--entrypoints.websecure.address=:443",
    # Redirect HTTP -> HTTPS
    "--entrypoints.web.http.redirections.entrypoint.to=websecure",
    "--entrypoints.web.http.redirections.entrypoint.scheme=https",
    # Certs
    "--certificatesResolvers.myresolver.acme.httpChallenge.entryPoint=web",
    "--certificatesresolvers.myresolver.acme.email=doom@c0mpl3x.one",
    "--certificatesresolvers.myresolver.acme.storage=/etc/traefik/acme/acme.json"
  ]

  lifecycle {
    ignore_changes = [ pid_mode, ulimit ]
  }
}