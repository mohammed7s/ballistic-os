# Signing keys

Ballistic builds are signed with our own keys, never GrapheneOS's and never the AOSP test keys.
The keys decide three things on the phone: which OS the bootloader accepts (verified boot), which
updates the OS accepts (OTA), and which apps may update system apps (APK signatures). The
procedure is GrapheneOS's (<https://grapheneos.org/build#generating-release-signing-keys>), run by
`scripts/sign.sh`.

## The rules

1. **Keys never go on the build box.** The box is a rented container on someone else's host. It
   produces unsigned `target_files` and `otatools`; signing happens on the signing laptop.
2. **One set per device model**, created once (`keys/blazer` for the Pixel 10 Pro). They cannot be
   replaced without flashing again, and flashing a different key means unlocking the bootloader,
   which **wipes the phone**.
3. **Lose them and the phone can never be updated again** (only wiped and re-flashed with new keys).
   Back them up offline right after creating them, and again whenever anything in the folder changes
   (it shouldn't).
4. Keys are encrypted at rest with a passphrase (scrypt + AES-256, GrapheneOS's `encrypt-keys`).
   The passphrase is typed only into the signing laptop's terminal: never in chat, a file, an env
   var in a script, or a commit.

## Where they are

| What | Where |
|---|---|
| Key store | `~/ballistic-keys/blazer/` on the signing laptop (Dell Latitude, "laptop A"); `chmod 700`, outside any git repo |
| Signing workspace (tools, unsigned and signed builds; no keys) | `~/ballistic-sign/` |
| Offline backup | owner's responsibility; record *where* (not the passphrase) here when done |

Contents of `~/ballistic-keys/blazer/`:

| File | Purpose |
|---|---|
| `releasekey`, `platform`, `shared`, `media`, `networkstack`, `bluetooth`, `sdk_sandbox`, `gmscompat_lib`, `nfc` (`.pk8` + `.x509.pem`) | APK/APEX signing keys, RSA 4096; `releasekey` also signs OTAs |
| `avb.pem` | verified boot (AVB) signing key, RSA 4096 |
| `avb_pkmd.bin` | AVB public key, flashed to the phone's `avb_custom_key` partition |
| `id_ed25519`, `id_ed25519.pub` | signs the factory image zip (`ssh-keygen -Y sign -n "factory images"`) |

Certificate subject: `CN=Ballistic`.

## Public fingerprints (safe to publish)

Filled in after key generation:

- Verified boot key hash (`sha256sum avb_pkmd.bin`; the phone's yellow boot notice shows this):
  `TBD`
- Factory image signing key: `TBD`

For comparison, official GrapheneOS's Pixel 10 Pro key hash is
`4e8ee8f717754052198ca6d2d3aaa232e2461b4293c0d6f297e519cc778de093`. If the phone shows that, it is
running official GrapheneOS, not our build.

## Creating them (once)

```bash
cd ~/Desktop/ballistic-os
BOX=root@<box> BOX_SSH="ssh -p <port> -i ~/.ssh/<key>" scripts/sign.sh fetch   # tools only
scripts/sign.sh keygen
```

`keygen` runs GrapheneOS's `make_key` (with a blank password, into tmpfs at `/dev/shm`), generates
`avb.pem` and `avb_pkmd.bin`, then encrypts everything with GrapheneOS's `script/encrypt-keys`
(at its first prompt, "old passphrase", press Enter) and creates the ssh key (same passphrase).
Only then are the files copied to `~/ballistic-keys/blazer/`; the tmpfs copy is deleted on exit,
including on failure. `keygen` refuses to run if the folder already exists.

Why not run `make_key` with the passphrase directly: it prints the passphrase back to the terminal
(`creating releasekey.pk8 with password [...]`). `encrypt-keys` reads it with `read -s`. The
resulting encryption is the same.

Swap: the laptop's swap file lives inside its LUKS-encrypted root, so anything paged out is
encrypted at rest. GrapheneOS suggests disabling swap during signing (`sudo swapoff -a`) if memory
allows.

## Signing a build

```bash
BUILD_NUMBER=<n> BOX=... BOX_SSH=... scripts/sign.sh fetch    # pulls releases/<n>/ from the box
BUILD_NUMBER=<n> scripts/sign.sh release                      # asks for the passphrase twice
```

`release` runs GrapheneOS's `script/generate-release.sh` with the keys decrypted into
`/dev/shm` (removed on exit) and writes, in `~/ballistic-sign/releases/<n>/release-blazer-<n>/`:
`blazer-install-<n>.zip` (+ `.sig`, the factory image to flash), `blazer-ota_update-<n>.zip` (full
OTA, for sideloading or an update server), `blazer-target_files.zip` (signed; keep it, deltas are
built from it), and `blazer-{stable,beta,alpha,testing}` channel metadata. It then checks the
factory image signature against our ssh key and prints the expected boot key hash.

## Backup checklist

- [ ] Copy `~/ballistic-keys/` to at least two offline media (e.g. two USB sticks), stored apart.
- [ ] Check the copies: `sha256sum ~/ballistic-keys/blazer/*` matches on each.
- [ ] Write the passphrase down on paper, stored apart from the media (it is not recoverable).
- [ ] Note here where the backups are (location only).
