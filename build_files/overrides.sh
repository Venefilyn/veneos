#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -eou pipefail


case "$BASE_IMAGE" in
*"/bazzite"*);;
*"/ucore"*)
  # NOTE: ucore refactored to dnf5 and incorrectly moved designated /etc files to root
  # If sysctl.conf is detected at root the bug likely still exists
  # https://github.com/ublue-os/ucore/issues/258
  if [ -f "/sysctl.conf" ]; then
    mkdir -p /etc/default
    mkdir -p /etc/systemd
    mkdir -p /etc/udev
    mv /default/* /etc/default
    mv /systemd/* /etc/systemd
    mv /udev/* /etc/udev
    mv sysctl.conf /etc
  fi
  ;;
esac

# NOTE: rpm-ostree puts conf files at toplevel, when bug below is fixed we can remove
# https://github.com/coreos/rpm-ostree/issues/5393
rm -f /40-rpmostree-pkg-usermod*.conf || true
