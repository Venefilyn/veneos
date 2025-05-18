ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-gnome"
ARG TAG_VERSION="latest"
# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files cosign.pub /

# Base Image
FROM ${BASE_IMAGE}:${TAG_VERSION} AS veneos
COPY system_files /

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-gnome"
ARG TAG_VERSION="latest"
ARG SET_X=""

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
