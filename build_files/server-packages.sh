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

# The superior default editor
dnf5 swap -y \
    nano-default-editor vim-default-editor
