# Builder stage for Rust binaries — toolchain stays out of the final image.
# CARGO_HOME is overridden because base-main pre-creates /root/.cargo as a
# non-directory entry that cargo refuses to overwrite.
FROM ghcr.io/ublue-os/base-main:latest AS rust-builder
ARG AUTOTILING_RS_REF=59cefd205247aea03d7e7fa26b878deef3b454de
ENV CARGO_HOME=/var/tmp/cargo-home
RUN dnf -y install cargo rust binutils git \
 && mkdir -p "$CARGO_HOME" \
 && cargo install --locked --root /opt/cargo-out tealdeer \
 && cargo install --locked --root /opt/cargo-out \
        --git https://github.com/ammgws/autotiling-rs.git \
        --rev "${AUTOTILING_RS_REF}" \
        autotiling-rs \
 && strip /opt/cargo-out/bin/tldr /opt/cargo-out/bin/autotiling-rs

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
COPY --from=rust-builder /opt/cargo-out/bin/tldr          /usr/bin/tldr
COPY --from=rust-builder /opt/cargo-out/bin/autotiling-rs /usr/bin/autotiling-rs

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Verify final image
RUN bootc container lint
