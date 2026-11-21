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

## Ubuntu build-sandbox correction and resume 2

Resume 1 passed the generic-image check and compiled adevtool's helper targets:
`ninja: 15m52.74s Build Succeeded: 7485 steps`. The enclosing adevtool command then rejected
Soong's stderr warning, `Build sandboxing disabled due to nsjail error.` Pipeline exit was 1
at `2026-11-21T13:21:30Z`. This is successful helper compilation, not phone-target compilation.

The detailed Soong log showed `mount('/', '/', ... MS_REC|MS_PRIVATE): Permission denied`.
The host kernel journal identified AppArmor's `unprivileged_userns` profile denying nsjail's
mount, setgid and dac_override operations. Ubuntu's
`kernel.apparmor_restrict_unprivileged_userns` was 1. Existing host profiles demonstrate the
named `flags=(unconfined)` plus `userns,` exception for applications needing namespaces.

Installed `/etc/apparmor.d/ballistic-build-nsjail`, owned by root, mode 0644:

```text
# Permit the pinned Android build sandbox to create its user namespace.
# Keep Ubuntu's restriction enabled for other unconfined programs.
abi <abi/4.0>,
include <tunables/global>

profile ballistic-build-nsjail /srv/ballistic/gos/prebuilts/build-tools/linux-x86/bin/nsjail flags=(unconfined) {
  userns,
}
```

Loaded with `apparmor_parser -r /etc/apparmor.d/ballistic-build-nsjail`. The same namespace,
UID/GID, bind-mount and hostname probe used by Soong then printed `Android Success`, exited 0
as `ballistic-build`, and the global restriction remained 1. Probe log:
`/srv/ballistic/logs/nsjail-probe-20261121.log`. This host rule attaches only to the named
source-tree nsjail executable; that tree remains writable by the dedicated build user.
No GrapheneOS source patch, stderr filtering or global AppArmor disablement was used.

Resume 2 uses the same code recipe `673b53a`, fourteen patches and tree checks. Runner:
`/srv/ballistic/build-resume2-20261121.sh`; unit `ballistic-build-2026112100-resume2.service`,
invocation `d7586131932a4e5181b78a17378ab447`. Log and exit record:
`/srv/ballistic/logs/build-2026112100-resume2.{log,exit}`. Existing helper outputs are retained.
Successful phone compilation, host tests, image packaging and device validation remain pending.

## Settings callback return types

Resume 2 passed vendor preparation with the repaired host sandbox and reached compilation of
Settings and the requested platform/test modules. It stopped at `Settings-core` Kotlin compilation:
`ScreenAutomationPage.kt:173` and `:220` declared `onCheckedChange` with inferred return types
incompatible with `SwitchPreferenceModel`'s `(Boolean) -> Unit`. Both lambda bodies end with
`revision++`, whose inferred result is an integer. The pipeline exited 1 at
`2026-11-21T15:26:50Z`, with 28,548 tasks done, one failed and 1,261 remaining in that stage.
These counts are not overall image-build progress or passing tests.

Settings patch 0003 explicitly declares `(Boolean) -> Unit` for both callbacks, retaining their
bodies. Source commit `b871e6e`; updated Settings tree
`45ab9f0a7178f15f099eb8ab8aa674b66064116b`. The first fourteen patches remain unchanged; the
series now has fifteen patches. The next resume skips already-successful vendor preparation
and retains the platform outputs. Actual Kotlin compilation and subsequent tests remain pending.

The fifteen-patch clean `git am` verification, idempotent reapplication and dirty-tree refusal
passed via `scripts/verify-patches.py`; the reported Settings tree matches the correction above.
