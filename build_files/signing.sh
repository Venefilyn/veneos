#!/usr/bin/bash

# shellcheck disable=SC1091
. /ctx/commit-wrapper.sh

set ${SET_X:+-x} -eou pipefail

# Signing
mkdir -p /etc/containers
mkdir -p /etc/pki/containers
mkdir -p /etc/containers/registries.d/

# TODO: Remove when things like uCore stops using /usr/etc for their policy.json
# Also remove all the other relations to /usr/etc
if [ -f /usr/etc/containers/policy.json ]; then
    cp /usr/etc/containers/policy.json /etc/containers/policy.json
fi

cat <<<"$(jq '.transports.docker |=. + {
   "ghcr.io/venefilyn": [
    {
        "type": "sigstoreSigned",
        "keyPaths": [
            "/etc/pki/containers/veneos.pub"
        ],
        "signedIdentity": {
            "type": "matchRepository"
        }
    }
]}' <"/etc/containers/policy.json")" >"/tmp/policy.json"

cp /tmp/policy.json /etc/containers/policy.json
cp /ctx/cosign.pub /etc/pki/containers/veneos.pub

tee /etc/containers/registries.d/veneos.yaml <<EOF
docker:
  ghcr.io/venefilyn:
    use-sigstore-attachments: true
EOF

mkdir -p /usr/etc/containers/
cp /etc/containers/policy.json /usr/etc/containers/policy.json
