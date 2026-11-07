# Signing keys

Ballistic builds are signed with our own keys, never GrapheneOS's and never the AOSP test keys.
The keys decide three things on the phone: which OS the bootloader accepts (verified boot), which
updates the OS accepts (OTA), and which apps may update system apps (APK signatures). The
procedure is GrapheneOS's (<https://grapheneos.org/build#generating-release-signing-keys>), run by
`scripts/sign.sh`.

## Current keys are TEST keys (7 Nov 2026)

The set in `~/ballistic-keys/blazer/` (CN=`Ballistic Test`) was made unattended for the first
test run on a test phone, at the owner's request: `PASSPHRASE_FILE=~/ballistic-keys/blazer.passphrase
scripts/sign.sh keygen`. The random passphrase sits next to the keys (mode 600), so the encryption
protects nothing against anyone who can read that folder. Before anything ships to a phone that
matters, make a new set with a typed passphrase (`scripts/sign.sh keygen` without
`PASSPHRASE_FILE`) and re-flash, which wipes the phone.

## Cloud test exception (7 Nov 2026, owner-authorized)

For the first phone installation, the owner explicitly chose cloud signing with a **new,
disposable test key set**, and clarified that the Pixel is a test phone. These keys are
separate from `~/ballistic-keys/blazer/` on the Latitude. The cloud host can access them;
they must never be promoted to production keys. Switching to another set requires a wipe.

Cloud key store: `/home/build/ballistic-cloud-test-keys/blazer/` on vast.ai instance
59466158; passphrase file alongside it, mode 600. Certificate CN: `Ballistic Cloud Test`.
Signing uses the pinned GrapheneOS `script/generate-release.sh`, via the current
`scripts/sign.sh` copied to `/home/build/logs/cloud-sign-tool.sh`. Log:
`/home/build/logs/sign-cloud-test.log`. The signed factory image is to be transferred
directly to the ThinkPad with checksum and signature verification before flashing.
The general rules below still apply to production keys. The cloud set is the explicit
exception for this test only. No unlock or flash is authorized until the owner confirms
backup and gives the final go-ahead.

A separate backup was copied to `~/ballistic-cloud-test-keys/` on the Latitude.
This is outside both repositories and does not replace `~/ballistic-keys/`.

Cloud test public fingerprints (7 Nov 2026):

- AVB key SHA-256: `9cffde575a2cad010e28e520879877126a1442dec0bd5b838adf616472ab4d9c`
- Factory signing public key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRBEDcA3aZJeLCxFddi6x1DL4aC5y7zlz6eWAbF7J5h`

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

Test keys of 7 Nov 2026:

- Verified boot key hash (`sha256sum avb_pkmd.bin`; the phone's yellow boot notice shows this):
  `e99c1c0d016619767569b7b90bac2afc0e433fdef244fb70ec0fda659eb8a2ec`
- Factory image signing key (`ballistic` in `allowed_signers`, namespace `factory images`):
  `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuLEEGkApOwSIs4o6Pfl48EHZ6gwK1R4EJiT1MhIviF`

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
