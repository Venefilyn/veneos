#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Installing RPM packages"

log "Enable Copr repos"

COPR_REPOS=(
    scottames/ghostty
)
for repo in "${COPR_REPOS[@]}"; do
    dnf5 -y copr enable "$repo"
done

log "Install layered applications"

# Layered Applications
LAYERED_PACKAGES=(
    borgbackup
    btop
    cosign
    direnv
    fira-code-fonts
    gh
    git-credential-libsecret
    gphoto2
    krb5-workstation
    libinput-devel
    libva-utils
    lld
    pipx
    podlet
    podman-remote
    pre-commit
    rbw
    rclone
    sqlite
    uv
    virt-install
    yq
    yubikey-manager
    zoxide
)

# General devel
LAYERED_PACKAGES+=(
    @development-tools
    ansible
    nodejs
    nodejs-npm
    pnpm
    yarnpkg
)

# Editors
LAYERED_PACKAGES+=(
    helix
    neovim
)

# Virtualization
LAYERED_PACKAGES+=(
    libvirt
    vagrant
)

# Terminal helpers
LAYERED_PACKAGES+=(
    atuin
    bat
    cheat
    grc
    ripgrep
    thefuck
)

# iPhone camera work
LAYERED_PACKAGES+=(
    libheif
)

# Terra
# Bazzite disabled this due to being unstable so lets re-enable it again
dnf5 config-manager setopt terra.enabled=1 terra-extras.enabled=1
LAYERED_PACKAGES+=(
    bun
    devpod
    devpod-desktop
    eza
    ghostty
    starship
)

# Cider music app
log "Import Cider Collective RPM key"
rpm --import /usr/share/veneos/RPM-GPG-KEY-CIDER-COLLECTIVE
LAYERED_PACKAGES+=(
    Cider
)

dnf5 install --setopt=install_weak_deps=False -y "${LAYERED_PACKAGES[@]}"

log "Disable Copr repos as we do not need it anymore"

for repo in "${COPR_REPOS[@]}"; do
    dnf5 -y copr disable "$repo"
done

log "Disable Cider Collective repo"
dnf5 config-manager setopt cidercollective.enabled=0

# Use flatpak steam with some addons instead
# rpm-ostree override remove steam
log "Removing Steam from Bazzite install, please use flatpak instead"
dnf5 -y remove steam
