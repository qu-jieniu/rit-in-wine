#!/usr/bin/env bash
# Shrink a baked RIT prefix without breaking it. Only removes things that are
# regenerable (ngen native images) or unused by a 2D WinForms+networking app
# (Direct3D / Vulkan / media-foundation / gstreamer). RIT is 32-bit i386, so the
# whole win64 side is dead weight -- but we keep it for now and prune by content.
set -u
P="${WINEPREFIX:-/opt/rit-prefix}/drive_c"

before=$(du -sm "$(dirname "$P")" | cut -f1)

# 1. .NET ngen native images -- regenerated on demand, safe to drop.
find "$P/windows/assembly" -type d -iname 'NativeImages*' -prune -exec rm -rf {} + 2>/dev/null
find "$P/windows/Microsoft.NET" -type d -iname 'NativeImages*' -prune -exec rm -rf {} + 2>/dev/null

# 2. Installer payloads cached *inside* the prefix (the dotnet MSIs etc).
rm -f "$P/windows/Installer"/*.msi "$P/windows/Installer"/*.msp 2>/dev/null

# 3. Wine gecko/mono (disabled; RIT uses real .NET).
rm -rf "$P/windows/system32/gecko" "$P/windows/syswow64/gecko" "$P/windows/mono" 2>/dev/null

# 4. Heavy Wine DLLs a 2D trading client never loads (Direct3D, Vulkan, media).
for d in d3d8 d3d9 d3d10 d3d10_1 d3d10core d3d11 d3d12 d3d12core d3dx9_* d3dx10_* d3dx11_* \
         ddraw dxgi wined3d d3dcompiler_* dxvk \
         vulkan-1 winevulkan \
         gstreamer winegstreamer mfplat mf mfreadwrite mfmediaengine mferror \
         quartz amstream evr dsound xaudio2_* x3daudio* xactengine* \
         opengl32 glu32; do
  rm -f "$P/windows/system32/"$d.dll "$P/windows/syswow64/"$d.dll 2>/dev/null
done

after=$(du -sm "$(dirname "$P")" | cut -f1)
echo "strip: ${before}MB -> ${after}MB raw"
