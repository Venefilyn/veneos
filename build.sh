#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"


### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/40/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
rpm-ostree install podman-compose podman-remote krb5-workstation libva-utils libvirt vagrant

# this would install a package from rpmfusion
# rpm-ostree install vlc

# flatpak related items
# add the fedora registry 
flatpak remote-add --if-not-exists fedora oci+https://registry.fedoraproject.org

# Bazzite installs Firefox from flathub, we need it from Fedora registry
# to make it work with Kerberos
flatpak install --reinstall -y fedora org.mozilla.firefox
#### Example for enabling a System Unit File
systemctl enable podman.socket

