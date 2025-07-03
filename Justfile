export repo_organization := env("GITHUB_REPOSITORY_OWNER", "Venefilyn")
export image_name := env("IMAGE_NAME", "veneos")
export repo_image_name := lowercase(repo_organization) / lowercase(image_name)
export repo_owner_id := "6598829"
export IMAGE_REGISTRY := "ghcr.io" / repo_image_name

export centos_version := env("CENTOS_VERSION", "stream10")
export fedora_version := env("CENTOS_VERSION", "42")
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

# Build Containers
[private]
rechunker := "ghcr.io/hhd-dev/rechunk:v1.2.2@sha256:e799d89f9a9965b5b0e89941a9fc6eaab62e9d2d73a0bfb92e6a495be0706907"
[private]
cosign-installer := "cgr.dev/chainguard/cosign:latest@sha256:c3811e893b72809faf1cbe7d22f32fc821b91b332d0f3456d75e45d75e556ec3"
[private]
syft-installer := "ghcr.io/anchore/syft:v1.28.0@sha256:bc71d110d271c823b3e3c58702aa8ad6bf06e2abd3c1ff7c8966420a9a57dc00"

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/
    rm -f ./*.sbom.*

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: aurora).
#   $tag - The tag for the image (default: lts).
#   $dx - Enable DX (default: "0").
#   $hwe - Enable HWE (default: "0").
#   $gdx - Enable GDX (default: "0").
#
# DX:
#   Developer Experience (DX) is a feature that allows you to install the latest developer tools for your system.
#   Packages include VScode, Docker, Distrobox, and more.
# HWE:
#   Hardware Enablement (HWE) is a feature that allows you to install the latest hardware support for your system.
#   Currently this install the Hyperscale SIG kernel which will stay ahead of the CentOS Stream kernel and enables btrfs
# GDX: https://docs.projectaurora.io/gdx/
#   GPU Developer Experience (GDX) creates a base as an AI and Graphics platform.
#   Installs Nvidia drivers, CUDA, and other tools.
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag $dx $hwe $gdx
#
# Example usage:
#   just build veneos-server testing 1 0 1
#
# This will build an image 'aurora:lts' with DX and GDX enabled.
#

# Build the image using the specified parameters
build $target_image=image_name $tag=default_tag $base_tag=tag:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    BUILD_ARGS=()
    BUILD_ARGS+=("--build-arg" "IMAGE_NAME=${target_image}")
    BUILD_ARGS+=("--build-arg" "IMAGE_VENDOR=${repo_organization}")
    BUILD_ARGS+=("--build-arg" "TAG_VERSION=${base_tag}")
    case "$target_image" in
    "veneos-server")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=ghcr.io/ublue-os/ucore-hci")
        ;;
    "veneos")
        BUILD_ARGS+=("--build-arg" "BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome")
        ;;
    esac
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    # Labels
    LABELS=()
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y\-%m\-%d\T%H\:%M\:%S\Z)")
    LABELS+=("--label" "org.opencontainers.image.description=${IMAGE_DESC:+""}")
    LABELS+=("--label" "org.opencontainers.image.documentation=https://raw.githubusercontent.com/${repo_organization}/${image_name}/refs/heads/main/README.md")
    LABELS+=("--label" "org.opencontainers.image.source=https://raw.githubusercontent.com/${repo_organization}/${image_name}/refs/heads/main/Containerfile")
    LABELS+=("--label" "org.opencontainers.image.title=${image_name}")
    LABELS+=("--label" "org.opencontainers.image.url=https://github.com/${repo_organization}/${image_name}")
    LABELS+=("--label" "org.opencontainers.image.vendor=${repo_organization}")
    LABELS+=("--label" "org.opencontainers.image.version=${target_image}.$(date -u +%Y\-%m\-%d)")

    LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/${repo_organization}/${image_name}/refs/heads/main/README.md")
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")

    keywords=("bootc" "ostree" "ublue" "universal-blue" "veneos")
    case "$target_image" in
    "veneos-server")
        keywords+=("coreos" "ucore")
        ;;
    "veneos")
        keywords+=("bazzite")
        ;;
    esac
    LABELS+=("--label" "io.artifacthub.package.keywords=$(IFS=, ; echo "${keywords[*]}")")
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/${repo_owner_id}?s=200&v=4")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "io.artifacthub.package.maintainers=[{\"name\": \"Freya Gustavsson\", \"email\": \"freya@venefilyn.se\"}]")
    LABELS+=("--label" "containers.bootc=1")

    podman build \
        "${BUILD_ARGS[@]}" \
        "${LABELS[@]}" \
        --pull=newer \
        --tag "localhost/${target_image}:${tag}" \
        .

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: image.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 image.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    if [[ $target_image == localhost/* ]]; then
        args+=" --local"
    fi

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: image.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 image.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "image.toml")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "image.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "iso.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "image.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "image.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu-docker)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "image.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "image.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Runs shell check on all Bash scripts
lint:
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'

# Runs shfmt on all Bash scripts
update-flatpaks:
    flatpak list --columns application --app > ./repo_files/flatpaks

# Get Cosign if Needed
[group('CI')]
install-cosign:
    #!/usr/bin/bash
    set ${SET_X:+-x} -euo pipefail

    # Get Cosign from Chainguard
    if ! command -v cosign >/dev/null; then
        # TMPDIR
        TMPDIR="$(mktemp -d)"
        trap 'rm -rf $TMPDIR' EXIT SIGINT

        # Get Binary
        COSIGN_CONTAINER_ID="$(podman create {{ cosign-installer }} bash)"
        podman cp "${COSIGN_CONTAINER_ID}":/usr/bin/cosign "$TMPDIR"/cosign
        podman rm -f "${COSIGN_CONTAINER_ID}"
        podman rmi -f {{ cosign-installer }}

        # Install
        just sudoif install -c -m 0755 "$TMPDIR"/cosign /usr/local/bin/cosign

        # Verify Cosign Image Signatures if needed
        if ! cosign verify --certificate-oidc-issuer=https://token.actions.githubusercontent.com --certificate-identity=https://github.com/chainguard-images/images/.github/workflows/release.yaml@refs/heads/main cgr.dev/chainguard/cosign >/dev/null; then
            echo "NOTICE: Failed to verify cosign image signatures."
            exit 1
        fi
    fi

# Install Syft
[group('CI')]
install-syft:
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Get SYFT if needed
    if ! command -v syft >/dev/null; then
        # Make TMPDIR
        TMPDIR="$(mktemp -d)"
        trap 'rm -rf $TMPDIR' EXIT SIGINT

        # Get Binary
        SYFT_ID="$(podman create {{ syft-installer }})"
        podman cp "$SYFT_ID":/syft "$TMPDIR"/syft
        podman rm -f "$SYFT_ID" > /dev/null
        podman rmi -f {{ syft-installer }}

        # Install
        just sudoif install -c -m 0755 "$TMPDIR"/syft /usr/local/bin/syft
    fi

# Generate SBOM
[group('CI')]
gen-sbom $input $output="": install-syft
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # Make SBOM
    if [[ -z "$output" ]]; then
        OUTPUT_PATH="$(mktemp -d)/sbom.json"
    else
        OUTPUT_PATH="$output"
    fi
    syft scan "{{ input }}" -o spdx-json="$OUTPUT_PATH" --select-catalogers "rpm,+sbom-cataloger"

    # Output Path
    echo "$OUTPUT_PATH"

# Add SBOM Signing
[group('CI')]
sbom-sign input $sbom="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # set SBOM
    if [[ ! -f "$sbom" ]]; then
        echo $sbom
        # sbom="$(just gen-sbom {{ input }})"
    fi

    # Sign-blob Args
    SBOM_SIGN_ARGS=(
       "--key" "env://COSIGN_PRIVATE_KEY"
       "--output-signature" "$sbom.sig"
       "$sbom"
    )

    # Sign SBOM
    cosign sign-blob -y "${SBOM_SIGN_ARGS[@]}"

    # Verify-blob Args
    SBOM_VERIFY_ARGS=(
        "--key" "cosign.pub"
        "--signature" "$sbom.sig"
        "$sbom"
    )

    # Verify Signature
    cosign verify-blob "${SBOM_VERIFY_ARGS[@]}"

# SBOM Attest
[group('CI')]
sbom-attest input $sbom="" $destination="": install-cosign
    #!/usr/bin/bash
    set ${SET_X:+-x} -eou pipefail

    # set SBOM
    if [[ ! -f "$sbom" ]]; then
        sbom="$(just gen-sbom {{ input }})"
    fi

    # Compress
    sbom_type="urn:ublue-os:attestation:spdx+json+zstd:v1"
    compress_sbom="$sbom.zst"
    zstd "$sbom" -o "$compress_sbom"

    # Generate Payload
    base64_payload="payload.b64"
    base64 "$compress_sbom" | tr -d '\n' > "$base64_payload"

    # Generate Predicate
    predicate_file="wrapped-predicate.json"
    jq -n \
            --arg compression "zstd" \
            --arg mediaType "application/spdx+json" \
            --rawfile payload "$base64_payload" \
            '{compression: $compression, mediaType: $mediaType, payload: $payload}' \
            > "$predicate_file"

    rm "$base64_payload"

    # SBOM Attest args
    SBOM_ATTEST_ARGS=(
        "--predicate" "$predicate_file"
        "--type" "$sbom_type"
        "--key" "env://COSIGN_PRIVATE_KEY"
    )

    : "${destination:={{ IMAGE_REGISTRY }}}"
    digest="$(skopeo inspect "{{ input }}" --format '{{{{ .Digest }}')"

    cosign attest -y \
        "${SBOM_ATTEST_ARGS[@]}" \
        "$destination/{{ repo_image_name }}@${digest}"

# Generate Tags
[group('Utility')]
generate-build-tags $tag=default_tag $github_number="0":
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    DATE="$(date -u +%Y\-%m\-%d)"
    TAGS=()

    if [[ "${github_number}" -gt 0 ]]; then
        SHA_SHORT="$(git rev-parse --short HEAD)"
        TAGS+=("pr-${github_number}-${tag}.${DATE}" "${SHA_SHORT}-${tag}.${DATE}")
    else
        if [[ $tag == stable ]]; then
            TAGS+=("latest")
        fi
        TAGS+=("${tag}" "${tag}.${DATE}")
    fi

    echo "${TAGS[@]}"

# Tag Images
[group('Utility')]
tag-images image_name="" default_tag="" tags="":
    #!/usr/bin/bash
    set -eou pipefail

    # Get Image, and untag
    IMAGE=$(podman inspect localhost/{{ image_name }}:{{ default_tag }} --format '{{{{.Id}}')

    # Tag Image
    for tag in {{ tags }}; do
        podman tag $IMAGE {{ image_name }}:${tag}
    done

    # Show Images
    podman images --filter id=$IMAGE

# Login to GHCR
[group('CI')]
@login-to-ghcr $user $token:
    echo "$token" | podman login ghcr.io -u "$user" --password-stdin

# Push Images to Registry
[group('CI')]
push-to-registry $image_name $default_tag $tags="" registry=IMAGE_REGISTRY:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    for tag in $tags; do
        podman push "${image_name}:${tag}" "docker://{{lowercase(registry)}}/${image_name}:${tag}"
    done

    digest=$(skopeo inspect docker://{{lowercase(registry)}}/${image_name}:${default_tag} --format '{{{{.Digest}}')

    echo "$digest"

[group('Utility')]
rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set ${SET_X:+-x} -eou pipefail

    # echo "::group:: Rechunk Prune"
    # podman run --rm \
    #     --privileged \
    #     --security-opt label=disable \
    #     --mount "type=image,src="localhost/${target_image}:${tag}",dst=/var/tree,rw=true" \
    #     --env TREE=/var/tree \
    #     --user 0:0 \
    #     {{ rechunker }} \
    #     /sources/rechunk/1_prune.sh
    # echo "::endgroup::"

    # echo "::group:: Create Tree"
    # podman run --rm \
    #     --privileged \
    #     --mount "type=image,src="localhost/${target_image}:${tag}",dst=/var/tree,rw=true" \
    #     --env TREE=/var/tree \
    #     --env RESET_TIMESTAMP=1 \
    #     {{ rechunker }} \
    #     /sources/rechunk/2_create.sh
    # echo "::endgroup::"

    echo "::group:: Rechunk"
    podman run --rm \
        --privileged \
        -v /var/lib/containers:/var/lib/containers \
        "quay.io/centos-bootc/centos-bootc:{{centos_version}}" \
        /usr/libexec/bootc-base-imagectl rechunk \
            localhost/${target_image}:${tag} \
            localhost/${target_image}:${tag}
    echo "::endgroup::"

# Quiet By Default
[private]
export SET_X := if `id -u` == "0" { "1" } else { env("SET_X", "") }
