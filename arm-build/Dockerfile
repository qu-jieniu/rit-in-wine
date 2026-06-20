# Cross-builds the patched http.sys for an arm64 Wine target.
#
# Parameterized so each arch builds in its own clean configure — with arm64ec in
# --enable-archs the cross-arch import-lib graph drags arm64ec winecrt0 into even
# the aarch64 target, so the two archs cannot share a configure.
#
#   ARCH=aarch64  WINE_BRANCH=wine-10.0   -> pure arm64 Linux Wine (validation)
#   ARCH=arm64ec  WINE_BRANCH=wine-11.0   -> CrossOver / Rosetta-free macOS (ship)
#
# arm targets require clang (llvm-mingw); gcc-mingw-w64 can't emit arm64/arm64ec PE.
ARG WINE_BRANCH=wine-10.0
ARG ARCH=aarch64
# PATCH=star  -> ensure host_matches accepts '*' (the fix)
# PATCH=nostar -> force host_matches to accept ONLY '+' (reproduce the old bug, for test controls)
ARG PATCH=star

FROM ubuntu:24.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
ARG WINE_BRANCH
ARG ARCH
ARG PATCH

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git curl xz-utils \
        build-essential pkg-config bison flex gettext perl python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# llvm-mingw provides aarch64- and arm64ec- targeting clang cross-compilers.
RUN set -eux; \
    asset=$(curl -fsSL https://api.github.com/repos/mstorsjo/llvm-mingw/releases/latest \
        | grep -o 'https://[^"]*ubuntu-[0-9.]*-x86_64.tar.xz' | head -1); \
    echo "fetching $asset"; \
    curl -fsSL "$asset" -o /tmp/llvm-mingw.tar.xz; \
    mkdir -p /opt/llvm-mingw; \
    tar xJf /tmp/llvm-mingw.tar.xz -C /opt/llvm-mingw --strip-components=1; \
    rm /tmp/llvm-mingw.tar.xz
ENV PATH=/opt/llvm-mingw/bin:$PATH

WORKDIR /build
RUN git clone --depth 1 --branch "$WINE_BRANCH" https://gitlab.winehq.org/wine/wine.git

COPY patches/ /build/patches/
# Extend the http.sys wildcard-host test to also accept '*' (RIT registers
# http://*:9999/). Done as an in-place edit rather than a context patch so it
# survives line drift across wine branches (10.0 uses url->url, 7.7 uses queue->url).
RUN cd wine && \
    if [ "$PATCH" = "nostar" ]; then \
        perl -i -pe "s/if \((\w+->url\[7\]) == '\+' \|\| \w+->url\[7\] == '\*'\)/if (\$1 == '+')/" dlls/http.sys/http.c && \
        ! grep -q "== '\*'" dlls/http.sys/http.c && \
        echo "BUG REINTRODUCED (only '+'):" && grep -n "url\[7\] == '+'" dlls/http.sys/http.c ; \
    else \
        perl -i -pe "s/if \((\w+->url\[7\]) == '\+'\)/if (\$1 == '+' || \$1 == '*')/" dlls/http.sys/http.c && \
        grep -q "== '+' || .*== '\*'" dlls/http.sys/http.c && \
        echo "PATCH OK (accepts '*'):" && grep -n "== '+' || " dlls/http.sys/http.c ; \
    fi

RUN cd wine && ./configure --without-x --without-freetype --disable-tests \
        --enable-archs="$ARCH" \
        > /build/configure.log 2>&1 || (tail -80 /build/configure.log; false)

RUN cd wine && make -j"$(nproc)" tools 2>&1 | tail -5
RUN cd wine && make -j"$(nproc)" "dlls/http.sys/${ARCH}-windows/http.sys" 2>&1 | tail -40

RUN mkdir -p "/out/${ARCH}" && \
    cp "wine/dlls/http.sys/${ARCH}-windows/http.sys" "/out/${ARCH}/http.sys" && \
    llvm-readobj --file-headers "/out/${ARCH}/http.sys" | grep -iE "Format|Arch|Machine" && \
    ls -la "/out/${ARCH}"

FROM scratch AS export
COPY --from=builder /out/ /
