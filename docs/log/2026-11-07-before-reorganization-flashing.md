# Test installation on Pixel 10 Pro

## Baseline flashed and relocked (7 Nov 2026)

Owner explicitly authorized wiping/installing plain build 2026110600 and physically
confirmed unlocking. Fastboot verified serial `56181FDCH0070R`, product `blazer`,
and unlocked=yes. The verified factory script ran with fastboot 35.0.2 and
`ANDROID_SERIAL=56181FDCH0070R`, in tmux `ballistic-flash-baseline`.
It finished rc=0 at 01:45:55 UTC, taking 2 min 4 s; all 17 super chunks succeeded.
Logs/status: `/home/ubuntu/ballistic-images/2026110600/flash.log` and
`flash-status.txt`. fwupd was stopped before unlocking to avoid USB interference.
After the owner confirmed relocking, fastboot verified `unlocked: no`, then
accepted the reboot command. Welcome-screen boot, displayed AVB fingerprint,
installed build number and OTA update testing still await verification.
Do not rerun the flash or unlock the device as part of monitoring.

## Earlier preparation record

Status (7 Nov 2026): cloud test signing succeeded at 00:27:34 UTC; direct download
started on the ThinkPad at 00:28:04 UTC. The download passed SHA-256 and detached-signature verification on the ThinkPad
at 01:14:21 UTC. Extraction and the extracted AVB key check passed; the transfer
finished at 01:16:54 UTC with rc=0 (48 min 50 s since the original start).
The original download began
00:28:04 UTC and suffered network interruptions; the final resume reused
1,284,326,400 bytes and reached verification in 508 s. Do not interpret rsync's
reported 4.3 MiB/s as wire throughput: it includes reused bytes. Overall elapsed
through verification was 46 min 17 s. Pixel USB was not visible in the latest check.
Destination: `/home/ubuntu/ballistic-images/2026110600/`; log: `transfer.log`,
tmux session: `ballistic-download`. Factory ZIP: 2,205,435,662 bytes; SHA-256:
`59ba9701c0ab31ea1989b6c14f7e74d032537a37cd386262d568709d2d006c67`.
The cloud verified its detached signature against the cloud test signing key.
The download script repeats SHA-256/signature verification against a separately
pinned public key, extracts the ZIP, then checks its AVB key hash. It never flashes.
Signed OTA (1,746,909,726 bytes) and signed target-files (5,172,769,055 bytes) remain
on the cloud disk under the same release directory. Test keys have a separately
verified backup on the Latitude. Standalone fastboot 35.0.2 is available on the
ThinkPad at `~/grapheneos-blazer/platform-tools/fastboot`; the system copy is older.
The extracted flash-all.sh was inspected: it checks blazer, requires fastboot >=35.0.1,
flashes avb_custom_key, erases userdata/metadata, and exits on errors. The available
standalone fastboot is 35.0.2. Pixel USB remains absent; connect it before device checks.
At this preparation stage no unlock or flash had yet been performed; see the
completed flash record above.

Follow https://grapheneos.org/install/cli for the exact device procedure.
Device: Pixel 10 Pro (`blazer`). Source tag: `2026110200`; build number:
`2026110600`. This is stock source, signed with our disposable cloud test keys;
it does not yet contain Ballistic's OS patches or assistant app.

## Preparation

1. Generate the signed factory install archive and full OTA using the pinned
   GrapheneOS `script/generate-release.sh`. See `keys.md` for the owner-authorized
   cloud test exception and the expected public-key fingerprints.
2. Transfer the install archive, detached signature, public signer file and
   checksums directly from the build host to the ThinkPad. Verify SHA-256 and
   `ssh-keygen -Y verify` with namespace `factory images` before extraction.
3. Keep the OTA and signed target-files archive for update testing and future
   delta generation. Keep a backup of the test signing keys separately from the
   original Latitude keys; never commit any private key or passphrase.
4. Confirm the connected device is `blazer`, platform-tools meet the official
   installation guide, and sufficient space is available. Do not target an emulator.
5. Obtain the owner's explicit confirmation that anything needed is backed up
   and that unlocking/wiping may proceed. A test-phone designation alone is not
   the final flash confirmation required for this session.

## Installation gate

After confirmation, follow the official guide: enable OEM unlocking, enter the
bootloader, unlock and confirm physically, run the supplied factory flash script,
then lock the bootloader and confirm physically before booting the installed OS.
Use the exact device serial with fastboot where supported; never run a generic
ADB command against an environment that also has an emulator attached.

The archive includes the AVB custom public key. Do not substitute the official
GrapheneOS key or the separate Latitude test key. Verify the yellow boot notice
against the cloud test key hash in `keys.md` and check the installed build number.

## Pitfalls and updates

- Unlocking and locking erase user data. A different signing key requires a wipe.
- Do not interrupt the flash script or skip errors and relock a partial install.
- Keep the source and signing logs. A watcher returning zero only confirms the
  watcher finished; check the actual build/signing completion marker.
- This build omits the Updater app (`OFFICIAL_BUILD` unset). Updates must be tested
  through recovery using the matching signed OTA; automatic updates are not set up.
- The custom OS is still GrapheneOS from stock source. Ballistic patches come later.

## Patched transfer preparation (7 Nov, approximately 01:32 UTC)

Owner requested downloading build 2026110700 too. Pixel USB 18d1:4ee1 is now
visible on ThinkPad, which has 116 GiB free. Patched signing is still packaging
its final install ZIP; OTA and signed target-files are already produced.
A separate `ballistic-download-patched` tmux job on ThinkPad waits for checksums,
then downloads into `/home/ubuntu/ballistic-images/2026110700/`, verifies the
pinned factory signature and checksums, extracts and checks the same AVB key.
Cloud `prepare-download-2026110700` publishes checksums only after sign-status
reports rc=0. Both jobs already exist; do not start duplicates. The restricted
ThinkPad download SSH key now points to the patched release directory, so the
completed baseline transfer script must not be rerun. Baseline files are retained.
At that point approval was pending; the owner subsequently authorized the plain
baseline only, which was flashed and relocked as recorded above.

## Patched image ready (7 Nov, 02:28:13 UTC)

The modified build 2026110700 install ZIP is fully downloaded and extracted at
`/home/ubuntu/ballistic-images/2026110700/blazer-install-2026110700/` on ThinkPad.
SHA-256 and pinned factory signature passed at 02:25:36 UTC; extracted AVB key
matched `9cffde575a2cad010e28e520879877126a1442dec0bd5b838adf616472ab4d9c`.
Transfer finished rc=0 at 02:28:13 UTC. ZIP size: 2,205,552,947 bytes. The final
resume reused 1,946,419,200 bytes and reached verification in 258 seconds;
rsync's aggregate rate includes reused bytes. The extracted flash-all.sh is
byte-for-byte identical to the verified baseline script (diff exit 0).
Owner reports the baseline boots successfully and authorized installing this
modified build; factory flashing wipes again. Awaiting interactive Fastboot and
physical unlock/relock confirmations. No modified build flash performed yet.

## Modified build flashed and relocked (7 Nov 2026)

Following the owner's installation authorization and physical unlock confirmation,
fastboot verified Pixel serial 56181FDCH0070R, product blazer, unlocked=yes.
The patched factory script ran in ThinkPad tmux `ballistic-flash-patched`, using
fastboot 35.0.2 and explicit ANDROID_SERIAL. It started 02:38:05 UTC and completed
02:40:10 UTC, rc=0 (2 min 5 s). All 17 super chunks succeeded. Logs/status are
`/home/ubuntu/ballistic-images/2026110700/flash.log` and `flash-status.txt`.
After the owner's physical lock confirmation, fastboot verified unlocked=no and
product blazer, then accepted reboot. Modified build boot, displayed key hash,
installed build number, on-device regression tests and OTA update testing are
still pending verification. Do not reflash as part of monitoring.
