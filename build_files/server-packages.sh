#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

SERVER_PACKAGES=(
    just
    jq
    skopeo
    tmux
    udica
    yq
)

dnf5 install --setopt=install_weak_deps=False -y "${SERVER_PACKAGES[@]}"

# The superior default editor
dnf5 swap -y \
    nano-default-editor vim-default-editor
