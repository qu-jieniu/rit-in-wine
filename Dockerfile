FROM lscr.io/linuxserver/webtop:ubuntu-xfce

ENV DEBIAN_FRONTEND=noninteractive \
    WINEPREFIX=/config/.wine \
    WINEARCH=win64 \
    WINEDEBUG=-all

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg2 \
        wine wine64 wine32 \
        winbind \
        winetricks \
        cabextract \
        xvfb \
        xdotool \
        p7zip-full && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY root/ /

RUN chmod +x /custom-cont-init.d/10-rit-install.sh /usr/local/bin/rit
