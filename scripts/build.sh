#!/bin/bash
# Build the unsigned release (user) variant for one device: vendor files via adevtool, then
# target-files and otatools, collected by GrapheneOS's script/finalize.sh into
# SRC_DIR/releases/BUILD_NUMBER/. Runs on the build box after sync.sh. Nothing here is
# signed; signing happens offline with sign.sh.
#
#   scripts/build.sh [SRC_DIR]        (default SRC_DIR: ~/gos)
#
# Env:
#   DEVICE        default blazer (Pixel 10 Pro)
#   BUILD_NUMBER  default YYYYMMDD00 for today (UTC). Must differ from the official
#                 GrapheneOS number so the build fingerprint shows it is ours.
#   CLEAN=1       rm -r out first (GrapheneOS recommends this for production builds)
#   SKIP_VENDOR=1 reuse vendor/google_devices/DEVICE from an earlier adevtool run
#
# OFFICIAL_BUILD is left unset on purpose: in this tree it only adds the Updater app, and
# the Updater must not point at releases.grapheneos.org with our keys (see grapheneos.org/build).

set -o errexit -o nounset -o pipefail

# adevtool refuses to run as root (cpio/debugfs behave differently); vast.ai only gives root,
# so the tree lives in an unprivileged user's home (see docs/building.md).
[[ $(id -u) != 0 ]] || { echo "run as an unprivileged user, not root" >&2; exit 1; }

src="${1:-$HOME/gos}"
device="${DEVICE:-blazer}"
export BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d)00}"
unset OFFICIAL_BUILD

cd "$src"
[[ "${CLEAN:-0}" == 1 ]] && rm -rf out

# nvm puts Node 24 (needed by adevtool) on PATH; the vast.ai image ships it in /opt/nvm
[[ -f /opt/nvm/nvm.sh ]] && source /opt/nvm/nvm.sh

# envsetup.sh, lunch and m reference unset variables
set +o nounset
source build/envsetup.sh

t0=$(date +%s)
if [[ "${SKIP_VENDOR:-0}" != 1 ]]; then
    [[ -d vendor/adevtool/node_modules ]] || yarnpkg --cwd vendor/adevtool/ install
    # adevtool is only an interactive alias in envsetup.sh; call it by path. It downloads the
    # stock factory image (~11 GB), builds its host tools (out_adevtool_deps/) and checks the
    # generated vendor module against vendor-specs/ hashes.
    vendor/adevtool/bin/run generate-all -d "$device"
fi
t1=$(date +%s)

lunch "$device-cur-user"
m target-files-package otatools-package
t2=$(date +%s)

script/finalize.sh
echo "build: $device $BUILD_NUMBER  adevtool $(( t1 - t0 )) s, m $(( t2 - t1 )) s"
ls -l "releases/$BUILD_NUMBER/"
