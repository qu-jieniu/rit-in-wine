FROM ubuntu:26.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates git build-essential pkg-config \
        bison flex gcc-multilib g++-multilib \
        gcc-mingw-w64 g++-mingw-w64 mingw-w64-tools \
        gettext perl python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /build/wine
COPY src/ /build/wine/

RUN ./configure --without-x --without-freetype --disable-tests --enable-win64 \
        > /build/configure.log 2>&1 \
    || (tail -40 /build/configure.log; false)

# The PE driver lives at dlls/http.sys/http.sys (a Windows PE32+ file built via
# mingw cross-compile). Its prerequisites need to be built explicitly because
# we're not doing a full `make all`.
RUN echo "==== tools/winebuild ==== " && \
    make -j"$(nproc)" tools/winebuild/winebuild 2>&1 | tail -3 && \
    test -x tools/winebuild/winebuild && echo "winebuild OK"
RUN echo "==== http.sys deps + driver ====" && \
    make -j"$(nproc)" \
        dlls/ntoskrnl.exe/libntoskrnl.cross.a \
        dlls/ws2_32/libws2_32.cross.a \
        dlls/http.sys/http.sys 2>&1 | tail -20 && \
    ls -la dlls/http.sys/

RUN mkdir -p /out && cp /build/wine/dlls/http.sys/http.sys /out/http.sys && ls -la /out

FROM scratch AS export
COPY --from=builder /out/ /
