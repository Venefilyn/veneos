#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

COPR_REPOS=(
    pgdev/ghostty
)
dnf5 -y copr enable "${COPR_REPOS[@]}"

# Layered Applications
LAYERED_PACKAGES=(
    borgbackup
    cockpit
    cockpit-machines
    cockpit-ostree
    cockpit-sosreport
    fish
    ghostty
    krb5-workstation
    libinput-devel
    libva-utils
    libvirt vagrant
    lld
    podman-compose
    podman-remote
    virt-install
)

# From nix
LAYERED_PACKAGES+=(
    ansible
    atuin
    bat
    btop
    bun
    cheat
    cosign
    devpod
    devpod-desktop
    direnv
    eza
    fira-code-fonts
    gh
    gphoto2
    helix
    neovim
    nodejs
    pre-commit
    rbw
    rclone
    ripgrep
    sqlite
    starship
    yq
    yubikey-manager
    zoxide
    zsh
)

dnf5 install --setopt=install_weak_deps=False -y "${LAYERED_PACKAGES[@]}"

dnf5 -y copr disable "${COPR_REPOS[@]}"

# Use flatpak steam with some addons instead
# rpm-ostree override remove steam
dnf5 -y remove steam

# Call other Scripts
# /ctx/flatpak.sh
