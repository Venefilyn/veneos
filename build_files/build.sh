#!/bin/bash

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

function echo_group() {
    local WHAT
    WHAT="$(
        basename "$1" .sh |
            tr "-" " " |
            tr "_" " "
    )"
    echo "::group:: == ${WHAT^^} =="
    "$1"
    echo "::endgroup::"
}

log() {
  echo "== $* =="
}

log "Starting VeneOS build process - Inspired by AmyOS and m2os"

log "Enable container signing"
echo_group /ctx/signing.sh

case "$BASE_IMAGE" in
*"/bazzite"*)
    echo_group /ctx/desktop-packages.sh
    echo_group /ctx/just-files.sh
    echo_group /ctx/desktop-defaults.sh
    ;;
*"/ucore"*) ;;
esac


log "Post build cleanup"
echo_group /ctx/cleanup.sh
