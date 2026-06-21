# Slimmest display variant of the v2 payload: a single Xvnc process replaces
# Xvfb + x11vnc + noVNC + websockify + openbox.
ARG BASE=rit-prefix:installed
FROM ${BASE}
RUN apt-get update && apt-get install -y --no-install-recommends \
        tigervnc-standalone-server iproute2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY rit-display.sh /usr/local/bin/rit-display
RUN chmod +x /usr/local/bin/rit-display
EXPOSE 5900 9999
ENTRYPOINT ["/usr/local/bin/rit-display"]
