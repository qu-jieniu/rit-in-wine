# Builds a patched http.sys (32-bit and 64-bit PE) for Wine 10.0.
# Only goal: produce /out/{i386,x86_64}/http.sys and /out/{i386,x86_64}/httpapi.dll
# (we won't ship httpapi but we build it for free).

FROM ubuntu:26.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Build deps. apt-get build-dep gets the full set; we add a few explicit ones
# in case the runtime archive doesn't expose source-deps inside the container.
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates git build-essential pkg-config \
        bison flex \
        gcc-multilib g++-multilib \
        gcc-mingw-w64 g++-mingw-w64 \
        mingw-w64-tools \
        gettext \
        perl python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --depth 1 --branch wine-10.0 https://gitlab.winehq.org/wine/wine.git

COPY patches/ /build/patches/
RUN cd wine && git apply /build/patches/0001-http.sys-fix-wildcard-and-teardown.patch && \
    git diff dlls/http.sys/http.c | head -40

# Configure once. Default config on a 64-bit host produces both arches as PE.
RUN cd wine && ./configure --without-x --without-freetype --disable-tests --enable-archs=i386,x86_64 \
        > /build/configure.log 2>&1 \
    || (tail -40 /build/configure.log; false)

# Wine 10 PE outputs live at dlls/<mod>/<arch>-windows/<file>. Build both
# arches by targeting those final paths directly; make resolves widl/tools
# transitively.
RUN cd wine && make -j"$(nproc)" \
        dlls/http.sys/i386-windows/http.sys \
        dlls/http.sys/x86_64-windows/http.sys 2>&1 | tail -30

# Stage the artifacts.
RUN mkdir -p /out/i386 /out/x86_64 && \
    cp /build/wine/dlls/http.sys/i386-windows/http.sys   /out/i386/http.sys && \
    cp /build/wine/dlls/http.sys/x86_64-windows/http.sys /out/x86_64/http.sys && \
    ls -la /out/i386 /out/x86_64

FROM scratch AS export
COPY --from=builder /out/ /
