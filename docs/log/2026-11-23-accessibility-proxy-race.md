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
This regression source has not yet been compiled or executed; do not report it as passing.

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

Build is in progress. Image checksum, delivery, boot and repeated cold/warm session checks are
pending. Compilation alone will not establish that the runtime failure is resolved. Full Stop,
OS revocation and sensitive-action approvals remain separate validation work.
