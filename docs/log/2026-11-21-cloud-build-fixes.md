# First installed-assistant cloud build corrections — 21 November 2026

The clean Contabo host synced GrapheneOS `2026110200`, applied the original twelve patches,
and matched all four recorded patched trees. Vendor preparation then failed while building
adevtool's host tools for `sdk_phone64_x86_64`, before the requested phone targets compiled.
Pipeline exit was 1 at `2026-11-21T12:45:59Z`.

## Generic system image partition check

`/srv/ballistic/gos/out_adevtool_deps/error.log` contains the full diagnostic:

```text
build/make/target/product/generic/Android.bp:1182:1:
module "aosp_shared_system_image" variant "android_common": includes non-generic modules:
    "com.android.extensions.computercontrol" from "VirtualDeviceManager",
```

Pinned `build/soong/filesystem/filesystem.go:1273-1303` permits a non-generic system_ext
module through a dynamic dependency or an included subpartition, not through the consent
app's `required` dependency. The separate nsjail warning was not this fatal error.

Frameworks patch 0008 removes that required edge. Build/make patch 0001 installs the existing
wrapper through `target/product/media_system_ext.mk`, guarded by the same
`RELEASE_PACKAGE_COMPUTER_CONTROL` flag as the consent app. The wrapper retains its own
required registration XML. The partition checks, library path and authorization remain unchanged.
The original twelve patches remain byte-for-byte unchanged; the series now has fourteen patches
across five projects. New build/make pin: `3ec7131c58881d0b5e751775cf76986fe3889517`, verified
against both the release-tag clone and the synced host project.

Source commits in local research clones:

- frameworks/base: `4ae6bb50f` (above the previous extension commits).
- build/make: `033d410` (above the newly recorded pin).

`python3 scripts/verify-patches.py /home/wakeel/src/ballistic-os-work` passed clean git-am,
idempotent application and dirty-tree refusal with all fourteen patches. Updated final trees:

- frameworks/base: `99e4421cae8e33f14b850c632c93c7b2ab3b6f6b`
- build/make: `9f3d93e7f283a883e5d16975ebd3b4f0f529c7b6`

Other final trees match the [extension source record](2026-11-21-installed-assistants.md).
This establishes patch application, not successful Soong compilation or runtime behavior.
The resume starts at vendor preparation, preserving the source download and helper build outputs.

## Resume 1

Recipe `673b53a` was archived and transferred; both machines reported SHA-256
`ed9edcc3c9cfee8658fab2b2b6f59df123adeb662cf1fb0450b6f920fa62978e`.
The host applied only the two missing patches using the prefix-aware application script.
The resume runner is `/srv/ballistic/build-resume1-20261121.sh`, launched as
`ballistic-build-2026112100-resume1.service` (invocation `424969c9db7d495aabc106579c69594b`)
at `2026-11-21T12:51:13Z`. It retains the original build number and skips source synchronization.
Log: `/srv/ballistic/logs/build-2026112100-resume1.log`; exit record uses the same basename
with `.exit`. The original failure log is retained. This records a restart, not a successful build.
