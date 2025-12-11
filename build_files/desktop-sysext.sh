#!/usr/bin/bash

# Create sysext dirs
mkdir -p /etc/extensions /run/extensions /var/lib/extensions

# Create sysupdate dir
mkdir -p /usr/lib/sysupdate.d

SYSEXTS_TRAVIER=(
  bitwarden
  tailscale
  vscodium
)
for s in "${SYSEXTS_TRAVIER[@]}"; do
    tee /usr/lib/sysupdate.d/"$s".transfer <<EOF
[Transfer]
Verify=false

[Source]
Type=url-file
Path=https://extensions.fcos.fr/extensions/$s/
MatchPattern=$s-@v-%w-%a.raw

[Target]
InstancesMax=2
Type=regular-file
Path=/var/lib/extensions.d/
MatchPattern=$s-@v-%w-%a.raw
CurrentSymlink=/var/lib/extensions/$s.raw
EOF
done
