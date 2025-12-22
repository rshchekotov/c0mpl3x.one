# C0MPL3X DevOps Repository

## Service Architecture

All services should be orchestrated using the Nix Home Manager,
specifically using Podman Quadlets.
The Home Manager should be managed inside a Nix Flake and should contain both
a user module `./users/doom`, as well a service module `./services`.
The service module would contain all the infrastructure provided,
while the user module would provide packages for the maintainer of the
server in order to streamline debugging, general operations on the server, etc.

## User Packages

One package that I would like to be available on the server is the `nushell`.
That's the shell I prefer to work with on the server.
I usually set up all my programs in `./users/doom/modules/programs/*`,
with there being a `default.nix` to gather all programs,
as well as `bash.nix` and `nushell.nix` to enable the nushell and to launch
it from bash, via `initExtra = "exec nu";`.

*I will expand this section as there will be more needs for user/dx packages.*

## Infrastructure

There should be numerous services available on the server.
First I'd like there to be Traefik for a Reverse Proxy,
Authentik for an Authentication service for all the following services.
I would also like there to be a Headscale instance behind Authentication.

### Secret Maintenance

Based on [Michael Stapelberg's Blog](https://michael.stapelberg.ch/posts/2025-08-24-secret-management-with-sops-nix) I decided to use [sops-nix](https://github.com/Mic92/sops-nix#use-with-home-manager) with [ssh-to-age](https://github.com/Mic92/ssh-to-age) to manage secrets within Git.

### Containerization

Containers are managed with Podman Quadlets (SystemD Units):
[GH Docs](https://github.com/containers/podman/blob/main/docs/source/markdown/podman-systemd.unit.5.md).

As quadlets are by nature just expansions to SystemD Units and Services
the following docs are also relevant:
- [SystemD Unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#)
- [SystemD Service](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#)
