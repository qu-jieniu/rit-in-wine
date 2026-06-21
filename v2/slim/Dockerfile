# Slimmest display variant of the v2 payload: a single Xvnc process replaces
# Xvfb + x11vnc + noVNC + websockify + openbox.
ARG BASE=rit-prefix:installed
FROM ${BASE}
RUN apt-get update && apt-get install -y --no-install-recommends \
        tigervnc-standalone-server iproute2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Cruft strip (safe — keeps all Wine; both arches are needed under new-WoW64,
# so do NOT remove x86_64-windows/x86_64-unix). Reflected in `podman export`.
RUN rm -rf /root/.cache /var/lib/apt/lists/* /var/cache/apt/* /tmp/* \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/* && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'C*' -exec rm -rf {} + 2>/dev/null || true

COPY rit-display.sh /usr/local/bin/rit-display
RUN chmod +x /usr/local/bin/rit-display
EXPOSE 5900 9999
ENTRYPOINT ["/usr/local/bin/rit-display"]
