# Platform validation checklist

Record results per source tag, recipe commit, signing identity and device. Use `passed`, `failed`,
`skipped` or `not run`; compilation and assumption skips are not test passes. The current twelve-patch
series has passed clean application and the lightweight public-SDK Java contract check. Its full-tree
build, Android tests and device checks are **not run**. See the [21 November record](log/2026-11-21-installed-assistants.md).
Historical [7 November results](log/2026-11-07-before-reorganization-regression-tests.md) apply only
to the earlier implementation: 11 focused Settings host passes, 3 skips, instrumentation compiled.

## Reproducible local checks

With the four existing pinned research clones (no full sync needed):

```bash
python3 scripts/verify-patches.py /path/to/research-clones
python3 scripts/check-client-api.py /path/to/patched/frameworks/base /path/to/pinned/android.jar --javac /path/to/javac
bash -n scripts/sync.sh scripts/build.sh
```

The first uses disposable sparse clones, applies all patches with `git am`, checks rerun behavior
and dirty-tree refusal. The second compiles headers derived from the entire pinned extension API
signature plus both fixture Java sources against the pinned public SDK. Generated headers are
never shipped. It is not the Soong/metalava, APK-packaging or hidden-API runtime test.

## Build and host tests

Use the [integration build commands](assistant-integration.md#fixtures-and-build-host-commands)
for the actual wrapper/stubs, ordinary APKs, Settings, PermissionController and service test packages.
In the configured full source environment:

```bash
atest --host -t --disable-upload-result \
  SettingsRoboTests:ComputerControlAgentPageProviderTest \
  SettingsRoboTests:ComputerControlAutomationTest \
  SettingsRoboTests:ScreenAutomationPageTest
```

Record tests and skips individually. The added Settings cases cover label/package search and
candidate exclusion; they do not exercise the Compose page on a device. Inspect that page on the
actual image: one selected-assistant switch, one searchable installed-target list with inline
switches, correct app label, no preselected assistant and all fresh grants off. App-info entry
points must lead to this same page. Verify refresh after role/package changes and returning from
assistant selection, empty search/results, denial messages and different-user contexts.

## Instrumentation — separate execution

On an explicitly authorized compatible device with matching platform/test signing, run:

```bash
atest -t --disable-upload-result \
  VirtualDeviceServicesTests:ComputerControlUserAllowlistTest \
  VirtualDeviceServicesTests:ComputerControlAllowlistControllerTest \
  VirtualDeviceServicesTests:ComputerControlSessionProcessorTest \
  VirtualDeviceServicesTests:ComputerControlSessionImplTest
atest -t --disable-upload-result \
  PermissionControllerMockingTests:com.android.permissioncontroller.tests.mocking.role.model.RoleParserTest
```

These are device tests. Building their APKs does not run them. Test identity adoption is limited
to the platform test suites; it must not be used for the ordinary assistant success flow.

New service regressions cover ordinary owners failing DeviceConfig alternatives without both
signer-bound switches, privileged compatibility, the candidate query granting no authority,
PermissionController protection even on super/test paths, pending consent revoked then regranted,
role removal despite a retained privileged grant, permission loss on a live session, other-user
isolation, revocation during construction, MODE_DEFAULT/MODE_ERRORED closure and global AppOp restriction callbacks. Existing
parameter, consent, signer, user and publication-race tests remain required. The new role-parser
case checks optional grant SDK bounds and platform role protection, explicitly skipping when the
feature permission is absent; it does not prove real role grant/revocation.

## Ordinary APK device matrix

Install the [fixtures](assistant-integration.md) normally under `/data/app`, with a signer distinct
from the platform. Record build/key/boot identity, APK SHA-256, certificate SHA-256, installer,
package flags, library registration, extension version and log output. Do not use `pm grant`,
install `-g`, shell role changes, root or AppOp mutations to make the successful flow pass.

| Case | Required observation |
| --- | --- |
| Fresh install, no role | Session denied; no owner/target grant |
| Role selected through Settings | Requested role permission granted; both switches still off |
| No-permission fixture selected | No undeclared permission grant and no session |
| Owner off, target off, missing consent | Each gate independently denies; switch does not answer consent |
| Authorized version 5 | System consent, notification and visible activity; target tree/screenshot and Count: 0 → Count: 1 after tap |
| Version 4, missing foreground/notification | Existing enforcement still rejects |
| Settings, consent app, PermissionController | Denied through ordinary, DeviceConfig, super-agent and test paths |
| Owner/target switch off | Pending request invalidated and affected live session closed; target withdrawal clears saved target consent |
| Role removed/replaced | Pending request invalidated and affected live session closed, including privileged holder retaining permission |
| Permission/AppOp/policy withdrawal | Pending and active authority ends; record callback latency and race results |
| Revoke then regrant before consent returns | Old pending request cannot publish; new request required |
| Same-signer update/reboot | Deliberate switches and saved consent retained; role grant reconciled |
| Uninstall/reinstall/different signer | No unintended owner or consent inheritance; accepted rotation lineage retains identity |
| OS upgrade with unchanged assistant APK path | Fingerprint-triggered role reconciliation grants eligible existing holder without enabling switches |
| Permission module update | Patched role configuration retained; record provenance and grant/revoke behavior |
| Other user, work profile, managed-device policy | No cross-user authority; upstream profile and policy denial retained |
| Installer restrictions | Record ADB versus file-manager/browser behavior; complete supported owner confirmations only |
| Stop, destruction, rapid Back/re-request | Session closes; late-created session is closed; no stale callback replaces current state |

Negative permission/AppOp/policy mutation may require platform test tooling. Label these runs
separately from the normal owner-authorized path. Retest privileged assistants using their
existing static grant and DeviceConfig route; they still need role, consent and protected-target
checks. The recipe does not claim all privileged/development paths require the ordinary switches.

## Integration and updates

The fixtures establish only the small API exercise once device results exist. Actual Ballistic
Screen/Hands adapters, task policy, models and AppFunctions are outside this change. Validate the
real client separately. Matching-key OTA and recovery checks also remain separate from image
compilation or factory flashing. Store outcomes, skips and failures under [log/](log/README.md).
