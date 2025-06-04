ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-gnome"
ARG TAG_VERSION="latest@sha256:2d84514f2322832fae215ed69514a24d4695ecf84b584eb943b92e60d42421d5"
# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files cosign.pub /

# Base Image
FROM ${BASE_IMAGE}:${TAG_VERSION} AS veneos
COPY system_files/etc /etc
COPY system_files/usr/share /usr/share

ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite-gnome"
ARG TAG_VERSION="latest"
ARG SET_X=""

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,src=/,dst=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
