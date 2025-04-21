# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files cosign.pub /

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome:stable AS veneos
COPY system_files /

ARG SET_X=""

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
