#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Enable podman socket"
systemctl enable podman.socket
