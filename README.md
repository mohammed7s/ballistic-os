# ballistic-os

**The GrapheneOS build for [Ballistic](https://github.com/mohammed7s/ballistic): a pinned GrapheneOS
release plus a small set of patches that put Android 17's assistant gates in the user's hands.**

This repository contains no Android source. It holds the recipe: which GrapheneOS tag to build,
the patches applied on top, the SELinux and device-config additions, and the scripts that build,
sign and publish updates. Everything here is intended to be readable by a GrapheneOS maintainer in
one sitting.

Status: **not started** (November 2026). Created so the layout and intent are public; the first
build (plan step 4) comes after the assistant's agent loop proves out on the emulator.
Apache 2.0. Not affiliated with or endorsed by GrapheneOS.

## Relationship to the other repository

| Repo | Contains | Ships as |
|---|---|---|
| [`ballistic`](https://github.com/mohammed7s/ballistic) | the assistant app, agent logic, emulator harness, design docs | an APK that runs on any Android; on stock GrapheneOS once the gates below are upstream |
| `ballistic-os` (this) | the build recipe: GrapheneOS tag + patches + scripts | a signed GrapheneOS image and OTA stream for Pixels, until the patches land upstream |

Design, specification and decisions live in `ballistic/docs/`; this repo links to them rather than
duplicating them.

## What the patches do

Android 17 already contains the machinery for a system-level assistant. On GrapheneOS it is
present and dead: gated by feature flags that are off in the release config and by allowlists
fetched from Google's DeviceConfig, which GrapheneOS never receives. The patches are deltas, not
replacements, so they survive whatever Google ships for the DMA in Android 18:

1. **Computer Control gate**: enable the `computer_control_access` and
   `computer_control_per_app_consent` flags; replace the DeviceConfig allowlists
   (`allowed_session_owner_apps`, `allowed_automatable_apps`) with a user-managed store and a
   Settings page; keep the assistant-role requirement.
2. **AppFunctions gate**: the same user-managed allowlist for callers.
3. **OnDeviceIntelligence provider**: let the user choose the on-device model service, as they
   choose a keyboard, instead of a hard-coded OEM component.
4. **Device config**: the Ballistic app as a privileged app with the permissions above allowlisted;
   TPU access for it; branding; Updater pointed at our OTA server.

Each patch is one commit, generated with `git format-patch`, against the pinned tag. Nothing
touches GrapheneOS's hardening, keystore, verified boot or attestation.

## Planned layout

```
MANIFEST            the GrapheneOS tag this release builds from
patches/
  frameworks_base/  0001-computer-control-user-allowlist.patch, 0002-appfunctions-gate.patch, …
  system_sepolicy/  assistant domains
  device_google_*/  product config, priv-app allowlist, bundled models
  packages_apps_Settings/   the Settings pages
scripts/
  sync.sh           repo init at the pinned tag, apply patches, report conflicts
  build.sh          build the release variant
  sign.sh           sign with keys that are never in this repo
  ota.sh            publish factory image + OTA metadata
  ci/               rebase bot: new GrapheneOS tag → sync → build → capability suite → publish
docs/
  keys.md           key generation and storage procedure
  flashing.md       flash, relock, recovery; the bricking pitfalls
```

## Build (when it exists)

```bash
scripts/sync.sh        # checks out GrapheneOS at $(cat MANIFEST), applies patches/
scripts/build.sh       # ~2 h on a 64 GB machine
scripts/sign.sh        # on the isolated signer
scripts/ota.sh         # publish
```

Requirements: a 64 GB+ RAM build machine, ~500 GB of disk, GrapheneOS's documented build
prerequisites, offline key storage.

## Contributing

Review of the patch set from anyone who knows GrapheneOS's tree is the most valuable contribution.
Issues welcome. Maintainer: [@mohammed7s](https://github.com/mohammed7s).
