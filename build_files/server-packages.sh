#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -eou pipefail

SERVER_PACKAGES=(
    borgbackup
    cockpit
    cockpit-files
    cockpit-machines
    cockpit-ostree
    cockpit-sosreport
    fish
    jq
    just
    python3-ramalama
    skopeo
    tmux
    udica
    yq
    zsh
)

dnf5 install --setopt=install_weak_deps=False -y "${SERVER_PACKAGES[@]}"

# The superior default editor
dnf5 swap -y \
    nano-default-editor vim-default-editor
