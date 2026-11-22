#!/bin/bash
# Build a development SDK-emulator image from the existing pinned, patched tree.
# Usage: scripts/build-emulator.sh SOURCE_DIR SEPARATE_OUTPUT_DIR
# This does not build/flash a Pixel or sign a release. Never cleans existing output.
set -eo pipefail
[[ $(id -u) != 0 ]] || { echo 'Run as an unprivileged build user.' >&2; exit 1; }
[[ $# == 2 ]] || { echo "Usage: $0 SOURCE_DIR SEPARATE_OUTPUT_DIR" >&2; exit 1; }
recipe=$(cd "$(dirname "$0")/.." && pwd)
src=$(realpath "$1")
export OUT_DIR=$(realpath -m "$2")
case "$OUT_DIR" in
    "$src"|"$src"/*|/) echo 'Output must be outside the source tree.' >&2; exit 1 ;;
esac
mkdir -p "$OUT_DIR"
exec 9>"$OUT_DIR/.ballistic-build.lock"
flock -n 9 || { echo 'Another emulator build owns this output directory.' >&2; exit 1; }
python3 "$recipe/scripts/apply-patches.py" "$src"
cd "$src"
export BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d)00}"
# This pin's default Siso executor cannot resolve its generated main.star with
# this separate absolute OUT_DIR. Use the supported local Ninja executor.
export SOONG_NINJA=ninja
unset OFFICIAL_BUILD
source build/envsetup.sh
lunch sdk_phone64_x86_64-cur-userdebug
[[ $(get_build_var RELEASE_PACKAGE_COMPUTER_CONTROL) == true ]] || {
    echo 'Computer Control packaging is disabled; refusing this configuration.' >&2; exit 1;
}
repo manifest -r -o "$OUT_DIR/source-manifest.xml"
m -j"${BUILD_JOBS:-18}" emu_img_zip computercontrol.extension.stubs.public
product_out=$(get_build_var PRODUCT_OUT)
system_ext_out=$(get_build_var TARGET_OUT_SYSTEM_EXT)
test -s "$system_ext_out/framework/com.android.extensions.computercontrol.jar"
test -s "$system_ext_out/etc/permissions/computercontrol.extension.xml"
test -s "$product_out/sdk-repo-linux-system-images.zip"
sha256sum "$product_out/sdk-repo-linux-system-images.zip" > "$OUT_DIR/image.sha256"
printf 'Emulator image built; boot and Computer Control runtime validation remain pending.\n'
cat "$OUT_DIR/image.sha256"
