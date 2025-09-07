[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/veneos)](https://artifacthub.io/packages/container/veneos/veneos)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/veneos-server)](https://artifacthub.io/packages/container/veneos-server/veneos-server)
[![Build VeneOS](https://github.com/Venefilyn/veneos/actions/workflows/build.yml/badge.svg)](https://github.com/Venefilyn/veneos/actions/workflows/build.yml)
[![Build VeneOS ISO](https://github.com/Venefilyn/veneos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/Venefilyn/veneos/actions/workflows/build-iso.yml)

# VeneOS - Venefilyn OS

A custom Fedora Atomic image designed for gaming, development and daily use. Based on Bazzite Gnome using https://github.com/ublue-os/image-template

Primarily intended for myself.

## Variants/tags

### Desktop

- Built on Fedora Atomic 42
- Uses [Bazzite](https://bazzite.gg/) as the base image
- GNOME 48
- Optimized for AMD GPU
- [Bazzite features](https://github.com/ublue-os/bazzite#about--features)

### Server

> [!CAUTION]
> `veneos-server` is still being developed and is yet to be tested in a live system.

- Built on Fedora CoreOS
- Uses [uCore Hyper-Coverged Infrastructure (HCI)](https://github.com/ublue-os/ucore)
- Cockpit is preinstalled
- `zsh` and `fish` is preinstalled
- Starship prompt is preinstalled

## Features

- Curated list of [Flatpaks](https://github.com/Veneflyn/veneos/blob/main/repo_files/flatpaks)
- Starship prompt, `fish`, `fuck` alias and Atuin history search (Ctrl+R). 
- POSIX compliant `fish` that starts through through `zsh`
- NodeJS and front-end tooling
- Setup command for git to work with SSH auth, SSH signing, and to work within containers without extra configuration

## Install

### Image Verification

All my images are signed with sigstore's [cosign](https://docs.sigstore.dev/cosign/overview/). You can verify the signature by running the following command:

```bash
cosign verify --key https://github.com/Venefilyn/veneos/raw/main/cosign.pub ghcr.io/veneos/IMAGE:TAG
```

### Desktop

From existing Fedora Atomic/Universal Blue installation switch to VeneOS image:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/venefilyn/veneos:latest
```

If you want to install the image on a new system download and install Bazzite ISO first:

<https://download.bazzite.gg/bazzite-stable-amd64.iso>

### Server
Based on CoreOS.

#### Existing installation

> [!NOTE]
> Do verify the image first to make sure it matches

From existing Fedora CoreOS installation, first rebase to one unverified registry

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/ublue-os/IMAGE:TAG
```

Now we have the container signatures and can use the signed one

```bash
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/IMAGE:TAG
```

#### New installation

For a completely new system, we follow [examples/veneos-server-autorebase.butane](examples/veneos-server-autorebase.butane) template.

1. Follow CoreOS docs for setting up both the [password and SSH key authentication](https://coreos.github.io/butane/examples/#users-and-groups).
1. Generate an Ignition file for the CoreOS installation using the Butane file
   ```bash
   podman run --interactive --rm quay.io/coreos/butane:release \
         --pretty --strict < veneos-server-autorebase.butane > veneos-server-autorebase.ign
   ```
1. Verify it works by installing CoreOS for [bare-metal](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/) inside a VM. Remember to share and mount the `.ign` file if you use ignition file or allowing access to host's local network.
1. Run `sudo coreos-installer install /dev/sda-or-other-drive --ignition-url https://example.com/veneos-server-autorebase.ign` (or `--ignition-file /path/to/veneos-server-autorebase.ign`). Your ignition file should work for any platform, auto-rebasing to the `veneos-server:stable` (or other `IMAGE:TAG` combo), rebooting and leaving your install ready to use.
1. Reboot the VM and verify the installation.
1. If it all works, repeat the bare-metal installation steps but for your server as we can now be relatively sure it works.

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
