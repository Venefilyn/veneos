#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

# Signing
mkdir -p /etc/containers
mkdir -p /etc/pki/containers
mkdir -p /etc/containers/registries.d/

cat <<<"$(jq '.transports.docker |=. + {
   "ghcr.io/venefilyn/veneos": [
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
  ghcr.io/venefilyn/veneos:
    use-sigstore-attachments: true
EOF
