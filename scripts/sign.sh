#!/bin/bash
# Offline signing, on the signing laptop. Keys never touch the build box.
#
#   scripts/sign.sh fetch    copy GrapheneOS's signing tools and the unsigned build from the box
#   scripts/sign.sh keygen   create the device's release keys in $KEYS/$DEVICE (once, ever)
#   scripts/sign.sh release  sign: factory image + full OTA in $WORK/releases/BUILD_NUMBER/
#
# keygen and release prompt for the key passphrase; run them in your own terminal.
# Test setups only: set PASSPHRASE_FILE and they run unattended. keygen writes a random
# passphrase there (mode 600, never printed); release reads it. A passphrase stored next to
# the keys protects nothing, so keys made this way are test keys.
#
# Env:
#   DEVICE        default blazer
#   BUILD_NUMBER  the number build.sh used (release, fetch)
#   WORK          signing workspace, default ~/ballistic-sign (tools + releases, no keys)
#   KEYS          key store, default ~/ballistic-keys (keys live in $KEYS/$DEVICE)
#   BOX           fetch only: ssh destination of the build box, e.g. root@host
#   BOX_SSH       fetch only: ssh command, e.g. "ssh -p 22 -i ~/.ssh/id_ed25519"
#   BOX_SRC       fetch only: source tree on the box, default /home/build/gos
#   CN            keygen only: certificate subject CN, default Ballistic

set -o errexit -o nounset -o pipefail

device="${DEVICE:-blazer}"
work="${WORK:-$HOME/ballistic-sign}"
keys="${KEYS:-$HOME/ballistic-keys}"

fetch() {
    : "${BOX:?set BOX}" "${BOX_SSH:?set BOX_SSH}"
    local box_src="${BOX_SRC:-/home/build/gos}"
    mkdir -p "$work"
    # Only what generate-release.sh and key generation need from the tree.
    local paths=(
        script
        prebuilts/build-tools/linux-x86
        prebuilts/build-tools/path/linux-x86
        prebuilts/jdk/jdk21/linux-x86
        development/tools/make_key
        external/avb/avbtool.py
    )
    [[ -n "${BUILD_NUMBER:-}" ]] && paths+=("releases/$BUILD_NUMBER")
    local p
    for p in "${paths[@]}"; do
        mkdir -p "$work/$(dirname "$p")"
        rsync -a --partial --info=progress2 -e "$BOX_SSH" "$BOX:$box_src/$p" "$work/$(dirname "$p")/"
    done
    if [[ -n "${BUILD_NUMBER:-}" ]]; then
        (cd "$work/releases/$BUILD_NUMBER" && sha256sum ./*.zip)
    fi
}

keygen() {
    local dest="$keys/$device"
    if [[ -e "$dest" ]]; then
        echo "$dest exists. Keys are created once; replacing them means wiping the phone." >&2
        exit 1
    fi
    [[ -x "$work/development/tools/make_key" ]] || { echo "run: $0 fetch" >&2; exit 1; }
    umask 077
    # Unencrypted keys exist only in tmpfs, until encrypt-keys has run.
    local tmp
    tmp="$(mktemp -d /dev/shm/ballistic-keygen.XXXXXXXXXX)"
    trap "rm -rf '$tmp'" EXIT
    source "$work/script/common.sh"   # signing_keys=(...)
    cd "$tmp"
    local key
    for key in "${signing_keys[@]}"; do
        # Blank password here; encrypt-keys below sets the real one without echoing it.
        # make_key's EXIT trap always exits 1, so check its output instead of its status.
        "$work/development/tools/make_key" "$key" "/CN=${CN:-Ballistic}/" <<< "" > /dev/null 2>&1 || true
        [[ -s "$key.pk8" && -s "$key.x509.pem" ]] || { echo "make_key $key failed" >&2; exit 1; }
    done
    openssl genrsa 4096 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -out avb.pem
    python3 "$work/external/avb/avbtool.py" extract_public_key --key avb.pem --output avb_pkmd.bin

    if [[ -n "${PASSPHRASE_FILE:-}" ]]; then
        [[ -s "$PASSPHRASE_FILE" ]] || (umask 077; openssl rand -base64 33 > "$PASSPHRASE_FILE")
        local pw
        pw="$(< "$PASSPHRASE_FILE")"
        # encrypt-keys reads: old passphrase (none), new, confirm
        printf '\n%s\n%s\n' "$pw" "$pw" | "$work/script/encrypt-keys" "$tmp" > /dev/null
        ssh-keygen -q -t ed25519 -C "Ballistic factory images ($device)" -N "$pw" -f "$tmp/id_ed25519"
        unset pw
    else
        echo
        echo "Choose the key passphrase. At the first prompt (old passphrase) just press Enter."
        "$work/script/encrypt-keys" "$tmp"
        echo
        echo "Same passphrase again for the factory-image signing key (ssh-keygen):"
        ssh-keygen -q -t ed25519 -C "Ballistic factory images ($device)" -f "$tmp/id_ed25519"
    fi

    mkdir -p "$keys"
    chmod 700 "$keys"
    mkdir "$dest"
    cp -a "$tmp"/. "$dest"/
    chmod 700 "$dest"
    chmod 600 "$dest"/*
    echo
    echo "Keys written to $dest. Back them up offline now; without them the phone cannot be updated."
    echo "Verified boot key hash (shown on the yellow boot notice):"
    sha256sum "$dest/avb_pkmd.bin" | cut -d' ' -f1
}

release() {
    : "${BUILD_NUMBER:?set BUILD_NUMBER}"
    [[ -d "$keys/$device" ]] || { echo "no keys in $keys/$device; run: $0 keygen" >&2; exit 1; }
    [[ -f "$work/releases/$BUILD_NUMBER/$device-target_files.zip" ]] || {
        echo "no unsigned build in $work/releases/$BUILD_NUMBER; run: BUILD_NUMBER=$BUILD_NUMBER $0 fetch" >&2
        exit 1
    }
    cd "$work"
    mkdir -p keys
    ln -sfn "$keys/$device" "keys/$device"
    export PATH="$work/prebuilts/jdk/jdk21/linux-x86/bin:$PATH"
    if [[ -n "${PASSPHRASE_FILE:-}" ]]; then
        # decrypt-keys takes $password; ssh-keygen -Y sign asks through SSH_ASKPASS
        local askpass
        askpass="$(mktemp /dev/shm/ballistic-askpass.XXXXXXXXXX)"
        trap "rm -f '$askpass'" EXIT
        printf '#!/bin/sh\ncat %q\n' "$PASSPHRASE_FILE" > "$askpass"
        chmod 700 "$askpass"
        password="$(< "$PASSPHRASE_FILE")" SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
            script/generate-release.sh "$device" "$BUILD_NUMBER" < /dev/null
    else
        script/generate-release.sh "$device" "$BUILD_NUMBER"
    fi

    local out="$work/releases/$BUILD_NUMBER/release-$device-$BUILD_NUMBER"
    local signers="$out/allowed_signers"
    echo "ballistic $(cat "$keys/$device/id_ed25519.pub")" > "$signers"
    ssh-keygen -Y verify -f "$signers" -I ballistic -n "factory images" \
        -s "$out/$device-install-$BUILD_NUMBER.zip.sig" < "$out/$device-install-$BUILD_NUMBER.zip"
    echo "expected boot key hash: $(sha256sum "$keys/$device/avb_pkmd.bin" | cut -d' ' -f1)"
    (cd "$out" && sha256sum "$device-install-$BUILD_NUMBER.zip" "$device-ota_update-$BUILD_NUMBER.zip")
}

case "${1:-}" in
    fetch|keygen|release) "$1" ;;
    *) echo "usage: $0 fetch|keygen|release" >&2; exit 2 ;;
esac
