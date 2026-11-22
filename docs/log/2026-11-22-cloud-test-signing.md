# Cloud test signing and ThinkPad delivery — 22 November 2026

The owner explicitly requested signing this build on the cloud after bringing the ThinkPad
online. This renews the cloud exception for the existing disposable test identity; production
key custody rules are unchanged. No new key pair was generated and no flashing was requested.

## Readiness and identity

ThinkPad SSH (`ubuntu@100.114.231.86`) succeeded. Root filesystem: 466 GiB total, 77 GiB available;
RAM: 31 GiB total, 22 GiB available. Destination:
`/home/ubuntu/ballistic-images/2026112100/`. Earlier build directories are retained.
A temporary user service `ballistic-transfer-awake-2026112100` holds a systemd sleep/idle
inhibitor for up to twelve hours; the transfer job releases it on completion or failure.
The inhibitor was observed active.

The Wakeel backup in `~/ballistic-cloud-test-keys/` matches the test identity recorded for
installation of build `2026110700`:

- AVB public key SHA-256: `9cffde575a2cad010e28e520879877126a1442dec0bd5b838adf616472ab4d9c`.
- Factory public key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILRBEDcA3aZJeLCxFddi6x1DL4aC5y7zlz6eWAbF7J5h`.

Encrypted test keys and their test passphrase file were streamed over host-key-pinned SSH to
`/dev/shm/ballistic-sign-2026112100` on the reinstalled Contabo host. No secret values were printed
or committed. The directory is mode 0700; files are mode 0600; ownership is the dedicated
non-sudo `ballistic-sign` account. Cloud swap is absent. The wrapper removes this temporary
store and its workspace key symlink on exit; upstream removes its decrypted tmpfs copies.
The original Wakeel backup is retained. These remain disposable test keys, not production keys.

## Signing job

Unsigned inputs and hashes are in the [image record](2026-11-22-unsigned-image.md).
A separate signing workspace `/srv/ballistic/sign-2026112100` reuses those archives and the
pinned upstream signing tools; it does not rebuild or overwrite the unsigned archives.
The job verifies unsigned SHA-256 records, runs `scripts/sign.sh release` with the existing
identity, checks the factory signature and the factory archive's embedded AVB public key,
then publishes the installation ZIP, detached signature, full OTA, public verification files
and three separate fixture APKs. Signed target-files remain in the cloud signing workspace.

Service: `ballistic-sign-2026112100.service`, invocation
`c846bb3514a64316ae2e9e0107f62b8e`. Started `2026-11-22T06:02:18Z`.
Wrapper, log and exit marker: `/srv/ballistic/sign-2026112100/{run.sh,sign.log,sign.exit}`.
The source archives passed checksum verification and release signing entered processing.
Launch and intermediate warnings do not establish signing success; inspect the final exit marker.

## Direct verified delivery

A new SSH download key was generated on the ThinkPad; its private key stays there.
Cloud user `ballistic-download` has a forced `/usr/bin/rrsync -ro` command restricted to
`/srv/ballistic/publish/2026112100`, with SSH forwarding/PTY capabilities disabled by `restrict`.
The ThinkPad separately received the pinned Contabo host key and the factory public signer from
Wakeel. A read-only rsync connection succeeded. No administrator SSH private key was copied.

ThinkPad user service `ballistic-download-2026112100.service`, invocation
`1aac9529223b4b79ae4c9575f8aea690`, runs `download.sh` in the destination. It waits for a READY
marker published only after signing and verification succeed, checks at least 20 GB free, and
uses resumable rsync. It then checks all SHA-256 values, verifies the factory signature against
the separately pinned signer, validates ZIP member paths, extracts to a new `extracted/`
subdirectory and verifies the extracted AVB public key. Logs/status are `transfer.log` and
`transfer.exit`. It issues no ADB, fastboot, unlock, flash or reboot commands.

The download job was observed active and waiting for the signed release. Both VPS and storage
remain retained. Successful signing, completed download and device behavior are still pending.

## Signing completed

Signing finished at `2026-11-22T06:49:06Z`, exit 0 (46m48s from launch). The factory signature
verified against the independently recorded existing factory signer, and the embedded AVB
public key matched `9cffde575a2cad010e28e520879877126a1442dec0bd5b838adf616472ab4d9c`.
The final temporary key store and workspace key symlink are absent. No upstream generate-release
or decrypt-keys temporary directories remained in `/dev/shm` at the post-signing check.

| Signed artifact | Bytes | SHA-256 |
|---|---:|---|
| `blazer-install-2026112100.zip` | 2,222,724,167 | `07edf0a310e1cc1cd3df5d8eb2330d67dad73037d66e5c0c6b0f7e68aab05c32` |
| `blazer-ota_update-2026112100.zip` | 1,760,497,133 | `087b854ad333d7af0f4643c58978f46be6d041b3e916af927d9e0b43b9ff13d7` |
| `blazer-target_files.zip` | 5,228,887,413 | `025906331781e74fc048281cd6232ddb018b27b22b401d97c769e0ebd06dd16e` |

The factory detached signature SHA-256 is
`fbdd557f62c9cd985d06526d7abb3cd606b30aa847e904ad05de043af0c942a1`.
Signed target-files remain in the separate cloud signing workspace for future update work.
The install/OTA/public verification files and separate fixture APKs are published under
`/srv/ballistic/publish/2026112100/`. The ThinkPad's automatic direct transfer started after
publication and was observed receiving data, with initial speeds around 1–2 MB/s.
Transfer verification and extraction are still pending; no phone command was issued.

## ThinkPad delivery completed

The transfer finished at `2026-11-22T07:23:59Z`, exit 0. On the ThinkPad, SHA-256 verification
passed for the installation ZIP, detached signature, full OTA, public AVB key and all three
fixture APKs. The factory signature passed against the separately pinned signer. Extraction
completed, and the extracted AVB key matched the expected existing test identity.

Ready paths on ThinkPad:

- Installation ZIP: `/home/ubuntu/ballistic-images/2026112100/blazer-install-2026112100.zip`
- Full OTA: `/home/ubuntu/ballistic-images/2026112100/blazer-ota_update-2026112100.zip`
- Extracted installation: `/home/ubuntu/ballistic-images/2026112100/extracted/blazer-install-2026112100/`
- Fixture APKs and verification files: `/home/ubuntu/ballistic-images/2026112100/`

The temporary sleep inhibitor service is inactive after completion. ThinkPad free space is
69 GiB; earlier builds are retained. The VPS, source, unsigned outputs and signed target-files
remain retained as requested. No phone command or flashing was performed. Installation choice,
current device identity/boot checks and runtime regression validation remain separate next steps.

## Connected-device precheck

After the owner connected the Pixel and accepted USB debugging, a read-only check through
ThinkPad ADB identified serial `56181FDCH0070R`, model Pixel 10 Pro, product/device `blazer`.
Installed fingerprint: `google/blazer/blazer:17/CP3A.261005.005/2026110700:user/release-keys`.
Build timestamp: `1794011628`; security patch: `2026-11-01`. Properties reported
`ro.boot.flash.locked=1`, `ro.boot.vbmeta.device_state=locked`, and verified-boot state `yellow`.
This establishes the previously installed modified build is booted, with a locked bootloader;
it does not validate its Computer Control behavior. Battery was 30%, USB powered and charging.

The phone's `/system/etc/security/otacerts.zip` was pulled to the new build's ThinkPad directory.
Its trusted certificate's DER SHA-256 exactly matches both the new OTA's
`META-INF/com/android/otacert` and the expected test release certificate:
`6f1bb5d843798d7b0d9d8543baf8a27588a8c16664074fdbfeaf702a95e67c90`.

OTA metadata: `ota-type=AB`, `pre-device=blazer`, target incremental `2026112100`,
post-timestamp `1795267410`, SDK 37 and security patch `2026-11-01`. The timestamp is newer
than the installed build and metadata requests no wipe. These checks support selecting the
recovery OTA update path with the existing locked bootloader, subject to recovery's own checks.
No reboot or update was issued during this precheck. Current installation/backup confirmation
is requested before applying the update, per `docs/flashing.md`'s before-installation procedure.

## Recovery OTA and boot verification completed

The owner confirmed there was nothing important to preserve, proceeded with the proposed
matching-key OTA, and selected Apply update from ADB in recovery. ThinkPad service
`ballistic-ota-install-2026112100.service` verified the OTA checksum, started sideload at
`2026-11-22T07:45:25Z`, and completed at `2026-11-22T07:51:45Z` with exit 0.
Its script, log and exit marker are in `/home/ubuntu/ballistic-images/2026112100/`
as `ota-install.sh`, `ota-install.log` and `ota-install.exit`. The owner separately confirmed
recovery displayed completion, selected Reboot system now, and reported that it worked.
No factory flash, wipe, unlock, relock or signing-key change was performed.

Subsequent read-only ADB checks on serial `56181FDCH0070R` returned:

```text
ro.build.version.incremental=2026112100
sys.boot_completed=1
ro.boot.flash.locked=1
ro.boot.vbmeta.device_state=locked
ro.boot.verifiedbootstate=yellow
library:com.android.extensions.computercontrol
/system_ext/framework/com.android.extensions.computercontrol.jar
```

This verifies the new build booted with the bootloader locked and the extension registered
and present. The custom-key boot state is unchanged from the precheck; these properties do
not independently read the displayed AVB public-key hash. The update sleep inhibitor was
stopped and confirmed inactive. The VPS and storage remain retained.

The owner is returning to app development. Use `docs/assistant-integration.md` for the ordinary
assistant contract. No fixture or real assistant was installed or exercised in this session;
role authorization, per-target consent, session notifications, observation/input and revocation
still require the device matrix in `docs/regression-tests.md`. Boot and library registration
are not evidence that the full Computer Control session flow works.
