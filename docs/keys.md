# Signing keys

The keys identify the OS accepted by verified boot, the updates accepted by the installed system,
and system APK signers. They are distinct from the assistant APK's ordinary release process.
Use the pinned upstream [key-generation procedure](https://grapheneos.org/build#generating-release-signing-keys)
through `scripts/sign.sh`.

## Custody and identity

- Production keys remain on a trusted signing machine, outside Git and off rented build hosts.
- Keep a separate store per device model and release identity. Losing the keys prevents updates
  under that identity; replacing them requires the appropriate reinstall/wipe procedure.
- Encrypt the store and enter its passphrase interactively. Keep independent offline backups and
  verify them. Do not put production passphrases in chat, scripts or adjacent files.
- Preserve the factory signing public key and AVB public-key hash separately so installation
  can be checked against a trusted expectation.

Defaults: `KEYS=~/ballistic-keys`, with device keys under `blazer/`;
`WORK=~/ballistic-sign` holds tools and release artifacts. Override only deliberately.
The script decrypts keys into temporary memory-backed storage and removes them on exit.

## Procedure

Fetch the matching tools, create keys once with `scripts/sign.sh keygen`, then sign each build
with `BUILD_NUMBER=<number> scripts/sign.sh release`. Full command templates and host variables
are in [build.md](build.md). `keygen` refuses an existing destination.

The store includes APK/OTA signing keys, `avb.pem`, public `avb_pkmd.bin`, and the factory-image
SSH signing key pair. `release` generates the factory ZIP/signature, full OTA, signed target-files
and channel metadata. These artifacts alone do not establish a functioning OTA service.

## Test keys are not production keys

The recorded initial installation used a separately authorized disposable cloud test key set.
Another local test set also exists in the historical record. They are different identities:
do not choose a key based on a convenient filename or promote either into production.
`PASSPHRASE_FILE` is a test-only convenience; storing it beside the keys provides no protection
against someone who can read both.

Exact historical locations, public fingerprints, backup evidence and the cloud-signing exception
are in the [7 November key record](log/2026-11-07-before-reorganization-keys.md).
Use that record only for identifying the corresponding test installation, not as a universal
instruction for a new build.
