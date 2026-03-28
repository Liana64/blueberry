# Allow build scripts and config files to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY files /files

# Base Image
FROM quay.io/fedora/fedora-bootc:43

### [IM]MUTABLE /opt
## Fedora symlinks /opt to /var/opt (mutable). Make it immutable for package manager use.
#RUN rm /opt && mkdir /opt

### BUILD
## Run modular build scripts to install packages and configure the system.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

### CONFIG FILES
## Copy all config files from files/system/*/etc/* into /etc/
RUN --mount=type=bind,from=ctx,source=/files,target=/ctx/files \
    for dir in /ctx/files/system/*/etc; do \
        [ -d "$dir" ] && cp -r "$dir"/* /etc/; \
    done && \
    chmod +x /etc/sway/scripts/* && \
    chmod +x /etc/NetworkManager/dispatcher.d/* && \
    chmod 600 /etc/usbguard/usbguard-daemon.conf /etc/usbguard/rules.conf && \
    ln -sf /etc/sway/scripts/sway-screenshot-all /usr/local/bin/sway-screenshot-all && \
    ln -sf /etc/sway/scripts/sway-screenshot-area /usr/local/bin/sway-screenshot-area && \
    systemctl enable blueberry-flatpak-install.service && \
    systemctl enable blueberry-user-setup.service && \
    restorecon -R /etc/ || true

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
