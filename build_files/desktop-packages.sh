#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

COPR_REPOS=(
    pgdev/ghostty
)
dnf5 -y copr enable "${COPR_REPOS[@]}"

# Layered Applications
LAYERED_PACKAGES=(
    ansible
    atuin
    bat
    borgbackup
    btop
    bun
    cheat
    cockpit
    cockpit-machines
    cockpit-ostree
    cockpit-sosreport
    cosign
    devpod
    devpod-desktop
    direnv
    eza
    fira-code-fonts
    fish
    gh
    ghostty
    gphoto2
    grc
    helix
    krb5-workstation
    libinput-devel
    libva-utils
    libvirt vagrant
    lld
    neovim
    nodejs
    podman-compose
    podman-remote
    pre-commit
    rbw
    rclone
    ripgrep
    sqlite
    starship
    thefuck
    virt-install
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
