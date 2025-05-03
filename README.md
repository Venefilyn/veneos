[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/veneos)](https://artifacthub.io/packages/container/veneos/veneos)
[![Build VeneOS](https://github.com/Venefilyn/veneos/actions/workflows/build.yml/badge.svg)](https://github.com/Venefilyn/veneos/actions/workflows/build.yml)
[![Build VeneOS ISO](https://github.com/Venefilyn/veneos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/Venefilyn/veneos/actions/workflows/build-iso.yml)

# VeneOS - Venefilyn OS

A custom Fedora Atomic image designed for gaming, development and daily use. Based on Bazzite Gnome using https://github.com/ublue-os/image-template

Primarily intended for myself.

## Base System

- Built on Fedora Atomic 42
- Uses [Bazzite](https://bazzite.gg/) as the base image
- GNOME 48
- Optimized for AMD GPU

## Features

- [Bazzite features](https://github.com/ublue-os/bazzite#about--features)
- Curated list of [Flatpaks](https://github.com/Veneflyn/veneos/blob/main/repo_files/flatpaks)
- Starship prompt, Fish, `fuck` alias and Atuin history search (Ctrl+R). Started through zsh
- NodeJS and front-end tooling
- Setup command for git to work with SSH auth, SSH signing, and to work within containers without extra configuration

## Install

From existing Fedora Atomic/Universal Blue installation switch to VeneOS image:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/venefilyn/veneos:latest
```

If you want to install the image on a new system download and install Bazzite ISO first:

<https://download.bazzite.gg/bazzite-stable-amd64.iso>

## Custom commands

The following `ujust` commands are available on top of most ublue commands:

```bash
# Install all VeneOS apps
ujust vene-install

# Install Flatpaks
ujust vene-install-flatpaks

# Setup VeneOS terminal configs
ujust vene-setup-cli

# Setup git
ujust vene-setup-git
```

## Package management

GUI apps can be found as Flatpaks in the Discover app or [FlatHub](https://flathub.org/) and installed with `flatpak install ...`.

## Acknowledgments

This project is based on the [Universal Blue image template](https://github.com/ublue-os/image-template) and builds upon the excellent work of the Universal Blue community.

Repository created with inspiration from multiple different bootc repositories

- https://github.com/astrovm/amyos
- https://github.com/m2Giles/m2os
- https://github.com/ublue-os/bazzite
