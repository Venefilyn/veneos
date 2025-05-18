#!/bin/bash

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "== $* =="
}

log "Starting VeneOS build process - Inspired by AmyOS and m2os"

log "Enable container signing"
/ctx/signing.sh

case "$BASE_IMAGE" in
*"/bazzite"*)
    /ctx/desktop-packages.sh
    /ctx/just-files.sh
    /ctx/desktop-defaults.sh
    ;;
*"/ucore"*) ;;
esac


log "Post build cleanup"
/ctx/cleanup.sh
