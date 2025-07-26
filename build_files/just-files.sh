#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Adding VeneOS just recipes"

echo "import \"/usr/share/veneos/just/vene.just\"" >>/usr/share/ublue-os/justfile

log "Hide incompatible Bazzite just recipes"
for recipe in "bazzite-cli" "install-coolercontrol" "install-openrgb" ; do
  if ! grep -l "^$recipe:" /usr/share/ublue-os/just/*.just | grep -q .; then
    echo "Error: Recipe $recipe not found in any just file"
    exit 1
  fi
  sed -i "s/^$recipe:/_$recipe:/" /usr/share/ublue-os/just/*.just
done
