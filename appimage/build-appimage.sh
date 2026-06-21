#!/usr/bin/env bash
# Runs inside a container built FROM rit-prefix:installed (Wine + RIT-baked
# prefix). Assembles a self-contained RIT.AppImage: bundled Wine + its .so deps
# + the prefix + AppRun. Outputs to /out.
set -eu

WINE=/opt/wine-stable
PFX=/opt/rit-prefix
APPDIR=/tmp/RIT.AppDir
rm -rf "$APPDIR"; mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib/x86_64-linux-gnu" "$APPDIR/usr/lib/i386-linux-gnu"

echo "==> bundle Wine (i386 + the loader; drop the x86_64-windows builtins -- RIT is 32-bit)"
cp -a "$WINE/bin" "$APPDIR/usr/"
mkdir -p "$APPDIR/usr/lib/wine"
cp -a "$WINE"/lib/wine/i386-unix    "$APPDIR/usr/lib/wine/"
cp -a "$WINE"/lib/wine/i386-windows "$APPDIR/usr/lib/wine/"
cp -a "$WINE"/lib/wine/x86_64-unix  "$APPDIR/usr/lib/wine/"   # the loader's unix side
cp -a "$WINE"/lib/*.so* "$APPDIR/usr/lib/" 2>/dev/null || true
# Wine's data files (NLS locale tables, fonts) -- wineserver needs l_intl.nls.
mkdir -p "$APPDIR/usr/share/wine"
cp -a "$WINE"/share/wine/* "$APPDIR/usr/share/wine/" 2>/dev/null || true

echo "==> bundle the RIT prefix"
cp -a "$PFX" "$APPDIR/rit-prefix"

echo "==> gather transitive .so deps (bundle everything except core glibc)"
gather() {
  local f="$1" arch="$2"
  ldd "$f" 2>/dev/null | awk '/=>/{print $3}' | grep -E '^/' | while read -r lib; do
    case "$lib" in
      *ld-linux*|*/libc.so*|*/libm.so*|*/libdl.so*|*/libpthread.so*|*/librt.so*|*/libresolv*) continue;;
    esac
    cp -Ln "$lib" "$APPDIR/usr/lib/$arch/" 2>/dev/null || true
  done
}
export -f gather
# 64-bit ELFs (loader + x86_64-unix)
find "$APPDIR/usr/bin" "$APPDIR/usr/lib/wine/x86_64-unix" -type f -exec sh -c 'file -L "$1" | grep -q "x86-64" && gather "$1" x86_64-linux-gnu' _ {} \; 2>/dev/null || true
# 32-bit ELFs (i386-unix backends)
find "$APPDIR/usr/lib/wine/i386-unix" -type f -exec sh -c 'file -L "$1" | grep -q "Intel 80386" && gather "$1" i386-linux-gnu' _ {} \; 2>/dev/null || true
# a couple of rounds to catch deps-of-deps
for round in 1 2; do
  find "$APPDIR/usr/lib/x86_64-linux-gnu" -name '*.so*' -exec sh -c 'gather "$1" x86_64-linux-gnu' _ {} \; 2>/dev/null || true
  find "$APPDIR/usr/lib/i386-linux-gnu"   -name '*.so*' -exec sh -c 'gather "$1" i386-linux-gnu' _ {} \; 2>/dev/null || true
done

echo "==> bundle libs Wine dlopens (not seen by ldd): X11, fonts, GL, crypto"
DLOPEN_LIBS="libX11.so.6 libXext.so.6 libXrender.so.1 libXcursor.so.1 libXfixes.so.3 \
  libXi.so.6 libXrandr.so.2 libXcomposite.so.1 libXinerama.so.1 libXxf86vm.so.1 \
  libxcb.so.1 libXau.so.6 libXdmcp.so.6 libxcb-xfixes.so.0 libxcb-randr.so.0 \
  libfreetype.so.6 libfontconfig.so.1 libpng16.so.16 libbrotlidec.so.1 libbrotlicommon.so.1 \
  libGL.so.1 libGLX.so.0 libGLdispatch.so.0 libglapi.so.0 libOSMesa.so.8 \
  libgnutls.so.30 libssl.so.3 libcrypto.so.3 libgmp.so.10 libhogweed.so.6 libnettle.so.8 \
  libp11-kit.so.0 libtasn1.so.6 libidn2.so.0 libunistring.so.5 libexpat.so.1 \
  libbz2.so.1.0 libuuid.so.1 libxml2.so.2 libs-asound.so libasound.so.2"
for arch in i386-linux-gnu x86_64-linux-gnu; do
  for l in $DLOPEN_LIBS; do
    cp -Ln /usr/lib/$arch/$l* "$APPDIR/usr/lib/$arch/" 2>/dev/null || true
  done
done

echo "==> AppRun + desktop + icon"
cp /build/AppRun "$APPDIR/AppRun"; chmod +x "$APPDIR/AppRun"
cp /build/rit.desktop "$APPDIR/rit.desktop"
cp /build/rit-icon.png "$APPDIR/rit.png"

echo "==> package with appimagetool"
APPIMAGETOOL=/tmp/appimagetool
curl -fsSL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -o "$APPIMAGETOOL"
chmod +x "$APPIMAGETOOL"
cd /tmp
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" /out/RIT-x86_64.AppImage 2>&1 | tail -15
ls -la /out/
