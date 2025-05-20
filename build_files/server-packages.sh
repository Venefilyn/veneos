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
