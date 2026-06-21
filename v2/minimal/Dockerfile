# Minimal-base v2 payload: debian-slim + winehq Wine 11 (--no-install-recommends)
# + only the runtime libs Wine actually needs, + the baked prefix. Avoids the
# gstreamer/mesa/cups recommends bloat to push below the 805 MB slim image.
# debian-slim (glibc) is leaner than ubuntu; Alpine is out (musl breaks Wine).
# RISK: a missing dlopen'd lib breaks RIT subtly — verified by running RIT.
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget gnupg2 && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -qO /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -qNP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        winehq-stable \
        tigervnc-standalone-server iproute2 \
        # 32-bit X/font libs winex11.drv dlopens (RIT is win32 under new-WoW64):
        libx11-6:i386 libxext6:i386 libxrender1:i386 libxfixes3:i386 \
        libxcursor1:i386 libxi6:i386 libxrandr2:i386 libxcomposite1:i386 \
        libxinerama1:i386 libxcb1:i386 libfreetype6:i386 libfontconfig1:i386 \
        libgnutls30:i386 \
        # 64-bit side (the new-WoW64 host process + Xvnc):
        libx11-6 libxext6 libxrender1 libfreetype6 libfontconfig1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* \
           /usr/share/doc/* /usr/share/man/* /usr/share/info/* && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'C*' -exec rm -rf {} + 2>/dev/null || true

# The baked, stripped win32 prefix (.NET 4.8 + RIT 1.8.464) from the proven image.
COPY --from=rit-prefix:installed /opt/rit-prefix /opt/rit-prefix

ENV WINEPREFIX=/opt/rit-prefix WINEARCH=win32 \
    PATH=/opt/wine-stable/bin:/usr/bin:/bin
COPY rit-display.sh /usr/local/bin/rit-display
RUN chmod +x /usr/local/bin/rit-display

EXPOSE 5900 9999
ENTRYPOINT ["/usr/local/bin/rit-display"]
