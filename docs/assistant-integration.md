# Ordinary assistant integration contract

Experimental recipe for GrapheneOS `2026110200`, extended 21 November 2026. The production path
is a normal, independently signed `/data/app` APK. No platform signature, preinstallation,
privapp allowlist, root, `pm grant`, shell identity, or `testOnly` flag is involved.
The source and fixture Java contract are checked. Cloud compilation now passed for the actual
wrapper/public stubs, Settings, PermissionController, consent app and requested platform test
modules after the recorded corrections. Full unsigned image packaging and the focused host tests passed (14 passed, 3 assumption skips).
All three ordinary fixture APKs compiled and passed signature/manifest checks. Release signing
and device behavior remain pending; see the
[image record](log/2026-11-22-unsigned-image.md). See the
[cloud build log](log/2026-11-21-cloud-build-fixes.md) and
[source evidence](log/2026-11-21-installed-assistants.md).

## Owner flow

1. Install a compatible assistant normally. In Settings > Apps > Default apps > Digital assistant
   app, select it. The role is not requestable through `RoleManager.createRequestRoleIntent` at
   this tag; open `Settings.ACTION_VOICE_INPUT_SETTINGS` instead.
2. Open Settings > Apps > Special app access > Screen automation. This is **one centralized page**:
   it shows the owner's selected assistant with its automation switch, followed by a searchable
   list of eligible installed targets, each with an inline switch. Search matches labels and
   package names. App-info entry points lead to this same page.
3. Turn on the selected assistant, then the individual target switches. Fresh owner grants are
   all off. No assistant is preselected or branded by this recipe. Role selection alone grants
   the permission, but does not enable either owner gate or grant target consent.
4. Allow the assistant's notifications through the normal runtime permission UI. Keep its
   activity visible. A version-5 request posts the required ongoing notification.
5. When the assistant requests a target, approve the separate system consent dialog (Allow once
   or Always allow). A target switch only permits requesting consent; it does not answer it.

The chosen app can read and act inside approved targets, including sensitive content and actions.
These gates are not a per-action policy or a promise that the assistant is trustworthy.

At the pinned Permission module, default-app UI calls `Role.getApplicationRestrictionIntentAsUser`,
which consults EnhancedConfirmationService. Its protected settings include dialer/SMS role selection,
but **not the assistant role**. No new restricted-settings bypass or exemption is added. Record the
actual installer and any restriction dialog on-device; if a supported owner confirmation is required,
complete it in Settings. ADB installation alone does not characterize file-manager/browser installation.

## Manifest and API

An exported activity handling `android.intent.action.ASSIST` with `CATEGORY_DEFAULT` qualifies for
this role at the pin. A qualifying `VoiceInteractionService` is another supported route; the fixture
uses the simpler activity. The role remains unavailable in managed profiles at this tag.

```xml
<uses-permission android:name="android.permission.ACCESS_COMPUTER_CONTROL" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<!-- Inside application: -->
<uses-library android:name="com.android.extensions.computercontrol" android:required="true" />
```

The library is `/system_ext/framework/com.android.extensions.computercontrol.jar`, registered by
`/system_ext/etc/permissions/computercontrol.extension.xml`. The `media_system_ext.mk` product
configuration installs it when `RELEASE_PACKAGE_COMPUTER_CONTROL` is enabled. The same flag
installs the consent app in the system partition. The existing XML also publishes feature
`com.android.extensions.computercontrol`.
ART at the pin assigns jars in `/system_ext/framework` the platform domain, allowing the wrapper's
internal framework calls. The calling APK remains ordinary, and binder authorization is unchanged.
Do not statically bundle the implementation: code copied into the APK has the application's domain.
No hidden-API exemptions are part of this contract.

Compile against the **compile-only** `computercontrol.extension.stubs.public` Java module, built from
`computercontrol.extension.stubs`' default generated source-jar output. That output contract is
verified in pinned Soong `java/droidstubs.go:setOutputFiles`. It compiles with `sdk_version: "current"`
and annotation libraries; it is not an installable jar. Public SDK types such as
`AppInteractionAttribution` and `DeviceId` exist in the pinned SDK. The signature-contract javac check
compiles every public signature and both fixture Java sources using that public SDK. It does not
substitute for building the actual metalava/Soong module.

For a source-tree APK:

```bp
sdk_version: "current",
min_sdk_version: "37",
target_sdk_version: "37",
libs: ["computercontrol.extension.stubs.public"],
uses_libs: ["com.android.extensions.computercontrol"],
```

For an external build, export the compiled stubs jar from
`out/soong/.intermediates/frameworks/base/libs/computercontrol/computercontrol.extension.stubs.public/android_common/javac/computercontrol.extension.stubs.public.jar`
and use Gradle `compileOnly(files("libs/computercontrol.extension.stubs.public.jar"))`, plus the
pinned API-37 public SDK. The full-tree build must verify this output path; no jar is distributed
by this repository. Exclude wrapper classes from the APK dex. Use `required="false"` only if the
app isolates all extension references behind a missing-library check and supports a real fallback.
The fixture deliberately requires the library, making a missing installation fail visibly.

At runtime, require `ComputerControlExtensions.getVersion() >= 5`, obtain
`getInstance(activity, 5)` (handle `null`), and use the versioned availability method. The deprecated
one-argument overload targets version 4 and is rejected by this recipe. Availability is not a grant
and does not replace error handling.

Build `ComputerControlSession.Params` with a name, up to six target package names, user-query
`AppInteractionAttribution`, and `NotificationParams`. The notification needs a channel, icon,
title, ongoing state and `setRequestPromotedOngoing(true)`; `hasPromotableCharacteristics()` must
pass. Attribution is required when the upstream app-interaction flag is enabled. Supplying this
metadata does not grant AppFunctions access. Call `requestSession` from the visible Activity.

Handle `onSessionPending(IntentSender)` by launching the supplied system consent UI. Handle both
synchronous authorization/argument failures and asynchronous creation errors. On success, install
lifecycle callbacks, launch only approved target packages, and close the session on Stop or owner
activity destruction. Close every screenshot `Image`. A callback arriving after local cancellation
must close its session. Treat closure/blocking as authoritative; do not keep issuing input or retry
without a new deliberate request. One concurrent session is supported at this pin.

## Fixtures and build-host commands

[Fixture sources](../fixtures/) contain an assistant, an otherwise identical assistant without the
Computer Control permission declaration, and a target with a local counter. They have no network,
model or external side effects. They are `android_app` modules, not `android_test`, and have no
`testOnly`, shared UID, privileged or platform-API settings. Their Soong signing certificate is
`testkey`, distinct from the platform key; verify that distinction in the actual build. They are
never added to `PRODUCT_PACKAGES`. For stronger installation provenance, re-sign only the fixture
APKs with a separate disposable fixture identity on an authorized signing machine. Do not use an
OS production key or place private keys in this repository.

On the adequately provisioned build host, with the pinned source synced and the recipe applied:

```bash
# From the source tree. Preserve an existing destination; use a fresh path if it exists.
cp -a /path/to/ballistic-os/fixtures packages/apps/OrdinaryComputerControlFixtures
source build/envsetup.sh
lunch blazer-cur-user
m computercontrol.extension.stubs.public com.android.extensions.computercontrol \
  VirtualDeviceManager PermissionController Settings \
  OrdinaryComputerControlAssistant OrdinaryComputerControlAssistantNoPermission \
  OrdinaryComputerControlTarget VirtualDeviceServicesTests PermissionControllerMockingTests \
  SettingsRoboTests
atest --host --disable-upload-result \
  SettingsRoboTests:ComputerControlAgentPageProviderTest \
  SettingsRoboTests:ComputerControlAutomationTest \
  SettingsRoboTests:ScreenAutomationPageTest
```

Use the lunch target supported by the pinned tree/build recipe if the recorded device target differs.
The APKs are under `out/target/product/blazer/system/app/<module>/<module>.apk` when explicitly built;
locate actual outputs with `rg --files out/target/product/blazer | rg 'OrdinaryComputerControl.*apk$'`
and record them rather than assuming packaging succeeded. `m` explicitly builds staging outputs;
this does not add these apps to the OS product. Check the final target-files package for their absence.

On a separately authorized compatible test device, verify build/key/boot identity first. Then:

```bash
adb shell pm list libraries
adb install /actual/output/OrdinaryComputerControlTarget.apk
adb install /actual/output/OrdinaryComputerControlAssistant.apk
adb shell pm path org.example.computercontrol.assistant
adb shell dumpsys package org.example.computercontrol.assistant
adb logcat -s OrdinaryControlFixture
```

Expected path: `/data/app/.../base.apk`. Record APK and signer SHA-256 hashes and confirm the
assistant signer differs from the installed platform/Settings signer. Do **not** use install `-g`,
`pm grant`, `cmd role add-role-holder`, appops mutation, root or test permission adoption to make the
successful flow work. Complete the owner flow above manually in Settings.

Before authorizing, Request target session must fail. After authorization and system consent,
Request target session should create the session. Observe target should report `Count: 0` and a
screenshot size. Tap target increment then Observe target should report `Count: 1`. This observation
and input sequence, and notification/foreground behavior, are **not yet device-tested**.

Repeat with the no-permission fixture: normal role selection must not give it the undeclared
permission or session access. Select the other assistant/None while a dialog is pending and while
a session is active. Repeat permission, AppOp, target, owner and policy withdrawal using appropriate
platform tests for states that ordinary UI cannot directly mutate. Shell-driven negative tests must
be logged separately from the normal production-flow result.

## State and compatibility expectations

- Same-signer updates and reboot retain signer-bound owner switches and saved consent. Role
  permissions are reconciled; an OS fingerprint change now forces role reconciliation even if APK
  paths did not change. Reconciliation regrants qualified existing holders, without selecting a
  new assistant or enabling switches. Permission module updates must retain this patch; an upstream
  replacement module is not a supported mixed version. Verify module/image provenance after OTA.
- Role change closes sessions for the affected user, including privileged clients retaining their
  permission. Ordinary role-only grants are revoked by PermissionController. Owner preferences are
  retained, so reselecting an assistant can reuse earlier explicit owner grants and saved consent.
  A pending request invalidated by withdrawal cannot be reused after reauthorization.
- Owner withdrawal stops sessions. Target withdrawal stops affected sessions and clears all saved
  assistant consent for that target in that user. Re-enabling the target requires fresh consent.
- Uninstall removes per-user owner and consent entries. A normal reinstall must be authorized anew.
  A different signer cannot inherit owner grants; certificate rotation with an accepted lineage
  preserves grants. These lifecycle expectations still require device evidence.
- Ordinary assistants require both owner switches even with DeviceConfig matches. Preinstalled
  privileged clients retain their DeviceConfig path plus role/permission/consent enforcement.
  Debug-super-agent and test-only paths remain development exceptions, never the fixture success
  path. Settings, the consent app and PermissionController are protected before those paths.
- Active closures are scoped to the affected UID/user/target. Global AppOp notifications close sessions for the affected user(s).
  Revocation generations conservatively invalidate pending construction across users. Service callbacks are asynchronous; latency and
  races must be exercised on-device. Managed profiles remain blocked by upstream policy.

Cleanup, when authorized: turn off the switches, choose the prior assistant or None, then uninstall
only the fixture packages. No device wipe, flash, root, production signing or artifact publication
is included in these instructions' execution scope. The Ballistic app's Screen/Hands adapters,
model integration and policy remain work in its own repository.
