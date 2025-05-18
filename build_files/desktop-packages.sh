#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Installing RPM packages"

log "Enable Copr repos"

COPR_REPOS=(
    pgdev/ghostty
)
dnf5 -y copr enable "${COPR_REPOS[@]}"

log "Enable repositories"
# Bazzite disabled this for some reason so lets re-enable it again
dnf5 config-manager setopt terra.enabled=1 terra-extras.enabled=1

log "Install layered applications"

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
    nodejs-npm
    pnpm
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
    yarnpkg
    yq
    yubikey-manager
    zoxide
    zsh
)
dnf5 install --setopt=install_weak_deps=False -y "${LAYERED_PACKAGES[@]}"

log "Disable Copr repos as we do not need it anymore"
dnf5 -y copr disable "${COPR_REPOS[@]}"

# Use flatpak steam with some addons instead
# rpm-ostree override remove steam
log "Removing Steam from Bazzite install, please use flatpak instead"
dnf5 -y remove steam
