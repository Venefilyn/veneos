#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/40/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 -y install podman-compose podman-remote krb5-workstation libva-utils libvirt vagrant

# I use flatpak steam with some addons instead
# rpm-ostree override remove steam
dnf5 -y remove steam

# this would install a package from rpmfusion
# dnf5 install vlc

# Copr packages
dnf5 -y copr enable pgdev/ghostty
dnf5 -y install ghostty
# Disable Copr repos so they don't end up enabled on the final image:
dnf5 -y copr disable pgdev/ghostty

# Install nix through Nix Determinate Installer
#curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

#### Example for enabling a System Unit File
systemctl enable podman.socket
