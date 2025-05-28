#!/usr/bin/bash
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

# Restore and setup directories
mkdir -p /tmp
mkdir -p /var/tmp \
&& chmod -R 1777 /var/tmp

log "Cleanup completed"

bootc container lint
ostree container commit
