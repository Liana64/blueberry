# Build scripts referenced via mount, not copied into final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/base-main:latest

LABEL org.opencontainers.image.title="blueberry"
LABEL org.opencontainers.image.description="Opinionated atomic Fedora image for Framework AMD AI 300 laptops"
LABEL org.opencontainers.image.source="https://github.com/liana64/blueberry"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Uncomment to make /opt immutable (Fedora symlinks /opt -> /var/opt by
# default; some packages like google-chrome/docker-desktop write there and
# get wiped on bootc deploy).
# RUN rm /opt && mkdir /opt

COPY system_files/ /

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Verify final image
RUN bootc container lint
