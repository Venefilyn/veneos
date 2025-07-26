#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -euo pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Starting system cleanup"

# Clean package manager cache
dnf5 clean all

# Clean temporary files
rm -rf /tmp/*
rm -rf /var/*
rm -rf /usr/etc
# FIXME: Somehow .nvimlog is added after installing. But only when done in CI - not locally.
rm -f /.nvimlog

# Restore and setup directories
mkdir -p /tmp
mkdir -p /var/tmp \
&& chmod -R 1777 /var/tmp

log "Cleanup completed"
