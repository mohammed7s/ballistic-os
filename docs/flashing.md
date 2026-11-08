# Installation and recovery procedure

Use the upstream [GrapheneOS CLI installation guide](https://grapheneos.org/install/cli) for the
exact device and platform-tools requirements. This page describes our artifact and identity checks;
it does not replace the upstream flashing sequence.

## Before installation

1. Build and sign the correct device image following [build.md](build.md).
2. Verify the factory ZIP checksum and detached signature against a separately trusted public
   signing key. Extract it and check its AVB public key against the intended release identity.
3. Confirm the physical device model and explicit serial. Do not accidentally select an emulator
   or another phone. Inspect the supplied factory script and its required fastboot version.
4. Confirm backups and authorization for the installation. Unlocking, relocking and key changes
   can erase data; a dated approval in the log does not authorize a new installation.

## Install and verify

Follow the official unlock, factory-flash and relock sequence, including physical confirmation.
Do not skip flash errors or relock an incomplete installation. Preserve the actual flash log and
exit status, then verify lock state, boot, installed build number and displayed public-key hash.
A successful fastboot reboot command does not prove that Android booted successfully.

Run the [platform validation checklist](regression-tests.md) after installation. This includes
runtime authorization checks and app integration separately from OS boot.

## Updates and recovery

Keep the matching full OTA, signed target-files and trusted public-key identity. The current build
script omits Updater; automatic OTA delivery is not configured. Validate recovery installation
of a matching-key OTA and the recovery path before describing updates as supported.
Use upstream recovery instructions for the exact device; do not substitute another signing key.

The [dated flash record](log/2026-11-07-before-reorganization-flashing.md) contains the initial
baseline and patched transfers/installations, including hashes and test-machine paths.
[CONTEXT.md](CONTEXT.md) gives the latest recorded verification boundary.
