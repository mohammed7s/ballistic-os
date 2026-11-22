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
