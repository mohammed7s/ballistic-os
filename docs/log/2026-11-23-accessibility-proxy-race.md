# Computer Control accessibility proxy race, 23 November 2026

The app session is authorized to build the separate development emulator on Contabo. This fix
does not build, flash or change the physical Pixel. The original emulator image and Pixel output
are retained.

## Reproduction

On custom API-37 emulator build `2026112200`, a fresh Clock agent task failed with empty
observations. A subsequent model-free fixture reproduced empty windows throughout its bounded
wait, despite the session reporting active and Clock drawing on its virtual display. At
10:58:41.889, logcat recorded a NullPointerException in
`AccessibilityManager.registerDisplayProxy`, via `ComputerControlSession$1.onActive`:
the `AccessibilityDisplayProxy` argument was null. Earlier successful sessions make this an
intermittent failure, not proof of a cold-start-only condition.

Source confirms that `ComputerControlSession` called remote `initialize(callback, surface)`
before assigning `mAccessibilityProxy`. An active callback can run before that remote call
returns. It publishes the active state and tries to register a still-null proxy, leaving the
client without accessibility windows.

App evidence and exact run identities are recorded separately in
[the Flash Lite pilot](../../../ballistic/docs/log/2026-11-23-flash-lite-computer-control.md).
The exception capture is retained on Latitude and ThinkPad under
`ballistic_runs/cc_flash_20261123/accessibility-proxy-failure.log`.

## Change and verification

Appended `frameworks_base/0009-computercontrol-initialize-accessibility-proxy-before-lifecycle.patch`:
initialize the proxy before publishing the callback. No public API, authorization gate or
platform hardening change. The preceding fifteen patches are unchanged.

Added `ComputerControlSessionTest.initialize_activeCallbackBeforeReturn_registersNonNullProxy`,
which invokes the callback inline during initialize and requires a non-null proxy registration.
This regression source compiled in `FrameworksCoreTests` (completion below), but has not been
executed; do not report it as passing.

`python3 scripts/verify-patches.py /home/wakeel/src/ballistic-os-work` passed clean git-am,
exact-prefix idempotence and dirty-tree refusal for all five repositories. Final frameworks/base
tree: `275c56c97c4e7cfb703842da2821ea80ba6db9a9`.
The Contabo source applied the same patch and reports that tree. Its commit identity is
`2ed035c84f884bc09694c31399cba119ad3ff681`; the local exported source commit is
`c70f7dd3a02d46cff739ce85bfe12bd30fec2392`. Different committer metadata explains the different
commit IDs. Initial remote application stopped because the build user had no Git identity;
the worktree remained clean. Re-running with command-scoped `Ballistic build` committer identity
succeeded, without repository-global identity or trust changes.

## Incremental build

Started 11:06:17 UTC on 23 November 2026, using existing source `/srv/ballistic/gos` and dedicated
output `out-emulator-20261122`. No clean operation; Pixel `out/` is untouched. Target remains
`sdk_phone64_x86_64-cur-userdebug`, build number `2026112300`, 18 jobs. The existing recipe builds
`emu_img_zip` and `computercontrol.extension.stubs.public` and checks packaged wrapper/XML.

- Unit: `ballistic-emulator-2026112300-proxy-fix.service`.
- Runner: `/srv/ballistic/build-emulator-20261123-proxy-fix.sh`.
- Log: `/srv/ballistic/logs/emulator-2026112300-proxy-fix.log`.
- Exit marker: `/srv/ballistic/logs/emulator-2026112300-proxy-fix.exit`.

Build completed successfully at 11:26:22 UTC, exit 0, with reported build duration 19:09.
The final graph completed 686 actions; Ninja's displayed remaining-time estimate was inaccurate.
Packaged wrapper/XML checks passed. ZIP size: 1,525,471,386 bytes. SHA-256:
`f7b9d36d8500603d89f2daf46326f29cdaff90fc42be35baceae9bf8bc71d03e`.

Transfer to a separate ThinkPad `~/ballistic-images/emulator-2026112300/` began after connectivity
returned, preserving the old image and AVD userdata. The receiver last reported 28,311,552 bytes
in `sdk-repo-linux-system-images.zip.part` at 11:28:40 UTC. SSH then stopped responding and the
transfer exited 255; two Tailscale pings also timed out. The final partial-file length is unknown.
Do not treat the partial file as verified or restart extraction. Resume only after inspecting it
and checking no transfer writer is still active; require the full expected SHA-256 before use.
Delivery/checksum verification, boot and repeated cold/warm session checks remain pending.
The original APK and policy are retained. A non-root sleep inhibitor was denied; an attempt to
start a bounded two-hour inhibitor through existing passwordless sudo lost its SSH connection,
so whether that unit started is unknown. Unit name: `ballistic-emulator-inhibit-20261123`.

The separate `FrameworksCoreTests` module compilation was started in the same dedicated emulator
output after the image job finished. Unit `ballistic-proxy-regression-20261123.service`; runner
`/srv/ballistic/build-proxy-regression-20261123.sh`; log and exit marker
`/srv/ballistic/logs/emulator-2026112300-proxy-regression.{log,exit}`. This build does not mean
the regression test has run. Compilation alone will not establish that the runtime failure is
resolved. Full Stop, OS revocation and sensitive-action approvals remain separate validation work.

The regression module build completed at 11:49:09 UTC, exit 0, with reported build duration
20:17 and 4,659 completed actions. APK:
`/srv/ballistic/gos/out-emulator-20261122/target/product/emu64x/testcases/FrameworksCoreTests/x86_64/FrameworksCoreTests.apk`.
Size: 44,387,362 bytes. SHA-256:
`002be88bb9b1032cb6d36112410d4bca862f1067b51868846e88c7e523157450`.
The next ThinkPad SSH attempt still timed out. Neither the repaired image nor this test package
has been installed there, and the test method has not run. No further OS compilation is needed
for the planned runtime checks unless they reveal another defect.
