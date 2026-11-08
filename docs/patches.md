# Reviewer guide: owner-controlled Computer Control

Target: GrapheneOS tag `2026110200` (Android 17). Eight patches in three repositories. Apply
order and commands: [patch index](../patches/README.md). Common questions: [FAQ](faq.md).
Review history of the earlier eleven-patch series:
[dated record](log/2026-11-07-patch-design-and-review-history.md).

## 1. The problem and the approach

Computer Control is AOSP code already present in GrapheneOS. An agent app opens a session, the
system creates a trusted virtual display, and the agent launches target apps there, reads their
accessibility tree, takes screenshots of that display and injects input into it. Nothing appears
on the user's own screen. Inference from the session design, not yet tested on a device: a
session's input reaches only its own display, not the default display.

On GrapheneOS the feature is unreachable for two reasons:

1. Three aconfig flags are off and read-only in the release configuration (§8.1).
2. The apps allowed to own a session, and the apps allowed to be automated, come from
   DeviceConfig keys in the `computer_control` namespace (§8.2). GrapheneOS never receives
   DeviceConfig, so both lists are always empty.

The patches follow four rules:

- **Add, never replace.** The DeviceConfig lookup stays. A second, owner-edited source is ORed
  into the same allowlist step. Devices that use DeviceConfig behave as before, and upstream
  changes to that code rebase more easily.
- **Empty by default.** Both owner lists start empty. With no entries, the feature is off.
- **Every existing check stays, in the same order** (§2).
- **No GrapheneOS-specific machinery.** No GosPackageState flags, no `strings_ext.xml` edits, no
  sepolicy change. Someone who knows AOSP's Computer Control can review it without knowing
  GrapheneOS internals.

## 2. The check order

A session request from agent A to automate target T passes every step, in this order. Steps
marked `[new]` are where the patches add a source or a check. Nothing is removed.

```
build time   A is preinstalled with ACCESS_COMPUTER_CONTROL in a privapp-permissions allowlist
             (build_release 0001 makes the permission exist; the image builder decides who has it)
                                         |
session      service checks the parcelled parameters itself              [new] fb 0004
creation     version 5 only, so a foreground window is required          [new] fb 0003
             caller uid owns A; A holds ACCESS_COMPUTER_CONTROL and POST_NOTIFICATIONS
             A holds the assistant role (default digital assistant)
             A allowed:  DeviceConfig list  OR  owner list "Allow screen automation"   [new] fb 0001
                                         |
per target   T is not Settings or the consent app                         [new] fb 0003
             T is not itself an allowed agent
             T is not on the DeviceConfig denylist
             T allowed:  DeviceConfig list  OR  owner list "Allow screen automation of this app"
                                         |
             AppOp COMPUTER_CONTROL for A: ignored or errored -> deny
             saved consent for (A, T)?  no -> AOSP consent dialog (build_release 0002)
                                         |
publication  role, permissions, AppOp, device policy and grants rechecked  [new] fb 0003, 0005
             any grant edit during construction rejects the session        [new] fb 0003
                                         |
             session runs on its own virtual display; launchApplication(T) rechecks the target
```

**Revocation.** Switching off an agent closes its sessions. Switching off a target closes every
session automating it and clears all agents' saved consent for it in that user. Removing one
saved (A, T) consent closes A's sessions on T, as in AOSP. Uninstalling an app drops its
entries for that user. Deleting a user drops that user's records from both stores.

## 3. What the user sees

1. Settings > Apps > Special app access > Screen automation lists the preinstalled apps that
   hold the permission, each "Not allowed". Every launchable app's App info page has a Screen
   automation entry reading "Not allowed". Settings and the consent app have none.
2. The owner opens the assistant's page and turns on "Allow screen automation". If the app is
   not the default digital assistant, its target list stays disabled, as in AOSP.
3. The owner opens App info > Screen automation for a target, such as a notes app, and turns on
   "Allow screen automation of this app".
4. The first time the assistant asks to automate that app, the AOSP consent dialog appears. The
   owner chooses Allow once or Always allow. Approved targets then appear on the assistant's
   page and can be removed one by one.
5. Turning either switch off ends running sessions at once.

There is no master switch. AOSP has none, and empty per-app lists already mean off.

## 4. build/release

### 0001 `cp2a: enable Computer Control with per-app consent and version 5`

**Changes.** Adds three value files under
`aconfig/cp2a/android.companion.virtualdevice.flags/`, each `ENABLED` and `READ_ONLY`, like the
six Computer Control flags already enabled there: `computer_control_access`,
`computer_control_per_app_consent` and `computer_control_support_v5`.

**Why.** Without `computer_control_access`, `ACCESS_COMPUTER_CONTROL` is not defined and the
service throws on every request (§8.1). Without `computer_control_per_app_consent`, the consent
permission, the per-target consent store and the Settings pages do not exist. Version 5 adds
the foreground-window requirement that frameworks/base 0003 makes mandatory.

**Security argument.** This only makes the feature reachable. Without the owner lists it stays
unusable on GrapheneOS, because DeviceConfig is empty. `READ_ONLY` means no runtime override.
`computer_control_role_assistant_requirement` is already enabled in cp2a.

**Leaves alone.** Every other flag.

**Rebase risk.** Low. If a later release config enables these flags, drop the matching files.

### 0002 `cur: include the Computer Control consent app`

**Changes.** Adds `flag_values/cur/RELEASE_PACKAGE_COMPUTER_CONTROL.textproto` set to true.
build/make then adds `VirtualDeviceManager` to `PRODUCT_PACKAGES`.

**Why.** For a target without saved consent, the service sends the user to a dialog
(`ACTION_REQUEST_ACCESS`). The dialog lives in `frameworks/base/packages/VirtualDeviceManager`,
which is built only when this flag is set. Without it, no request can ever be approved.

**Security argument.** It is the AOSP dialog, platform-signed. It hides non-system overlays and
filters touches when obscured. It runs on the default display, which a session's input should
not reach (inference, see §1).

**Leaves alone.** The dialog's code and behaviour.

**Open point.** A forum report suggests the app may already be present on GrapheneOS, which
contradicts the source at this tag. See the [FAQ](faq.md#is-the-consent-app-already-in-grapheneos).

**Rebase risk.** Low. Placed in `cur` because GrapheneOS's own build-flag values live there.

## 5. frameworks/base

All paths are under `services/companion/java/com/android/server/companion/virtual/computercontrol/`
unless stated. Tests are under `tests/VirtualDeviceTests/services/` and run as
`VirtualDeviceServicesTests`, an instrumentation suite.

### 0001 `computercontrol: consult a user allowlist next to DeviceConfig`

**Changes.**
- New `ComputerControlUserAllowlist`: two per-user lists, agents and targets, empty by default.
- Each entry stores the SHA-256 digests of the app's signing certificates when the owner allowed
  it. Matching uses `SigningDetails.hasAncestorOrSelfWithDigest`. A key rotation with the old
  certificate in its lineage keeps the entry. A different app reusing the package name does not
  inherit it.
- Stored with `AtomicFile` at `/data/system/computercontrol/user_allowlist.xml`, beside the
  existing fallback files. Loaded once at boot on the background executor and written on
  change. A corrupt or unreadable file reads as empty.
- `ComputerControlAllowlistController` ORs it into the two existing allowlist points:
  `isPackageApprovedToRunAutomation` for agents and `isPackageInAutomatableAppList` for targets.
  An allowed agent is never a target. The DeviceConfig denylist is still checked first and wins.
- Entries are dropped when the package is removed for that user.
- `dumpsys virtualdevice` prints both lists.

**Why.** On GrapheneOS the DeviceConfig lists are always empty. Replacing that lookup would
conflict with every upstream change to it and remove the vendor path from devices that use it.

**Security argument.** Empty by default. Only callers with a signature permission can add
entries (0002). Bound to signers. Fails closed on corrupt storage. Per user.

**Leaves alone.** DeviceConfig and fallback files, the denylist, test-only agents, super agents
(debuggable builds only), the role check, the AppOp, the consent store and dialog,
`MAXIMUM_CONCURRENT_SESSIONS` and `MAX_TARGET_PACKAGES`.

**Files.** `ComputerControlUserAllowlist.java` (new), `ComputerControlAllowlistController.java`,
`ComputerControlSessionProcessor.java`, `ComputerControlUserAllowlistTest.java` (new).

**Tests.** `ComputerControlUserAllowlistTest`: empty by default, signer and user binding, roles
kept separate, key rotation, removal, per-user package removal, persistence, corrupt file.

**Rebase risk.** Moderate. Two hook points in the allowlist controller.

### 0002 `computercontrol: let the user manage the user allowlist`

**Changes.** Four methods on `IComputerControlConsentManager`, its `ComputerControlConsentManager`
interface and the `VirtualDeviceManager` client, implemented in `VirtualDeviceManagerService`
and `ComputerControlSessionProcessor`: get and set for agents, get and set for targets.
- `@EnforcePermission(MANAGE_COMPUTER_CONTROL_CONSENT)`, a signature permission held by Settings
  and the consent app. Acting on another user also needs `INTERACT_ACROSS_USERS_FULL`.
- No-ops while `computer_control_access` is off.
- Withdrawing an agent closes its sessions. Withdrawing a target closes every session automating
  it. This reuses the loop that existing consent removal uses.
- The getters report the owner list only, not DeviceConfig, so a Settings switch shows exactly
  what the owner chose.

**Why.** Settings needs a way to edit the lists. The consent manager is where the existing
per-agent consent methods already live, behind the same permission.

**Security argument.** No new permission and no new caller class. The API is `@hide`. An agent
cannot allow itself without a signature permission. Revocation affects live sessions.

**Leaves alone.** Existing consent-manager methods.

**Files.** `core/java/android/companion/virtual/computercontrol/ComputerControlConsentManager.java`,
`IComputerControlConsentManager.aidl`, `core/java/android/companion/virtual/VirtualDeviceManager.java`,
`VirtualDeviceManagerService.java`, `ComputerControlSessionProcessor.java`.

**Rebase risk.** Low to moderate. AIDL additions only.

### 0003 `computercontrol: harden revocation, user lifecycle and session creation`

**Changes.**
- Settings and the consent app are rejected as targets before any other check, even if
  DeviceConfig lists them.
- Withdrawing a target's switch clears every agent's saved consent for it in that user.
- Package removal is handled for every user. Deleting a user removes its records from the owner
  list and the consent store. Session closures are scoped to the affected user.
- Version 4 requests are rejected, so the version 5 foreground-window requirement always applies.
- Owner, target and consent are checked again just before a constructed session is published.
  "Allow once" is preserved: only targets approved by the current dialog skip the saved-consent
  lookup.
- Creation reserves capacity under the `mSessions` lock and constructs outside it. An
  authorization generation, bumped by every grant edit, rejects any creation that overlaps an
  edit. A rejected session is closed outside the lock.

**Why.** Session creation is asynchronous. Without these changes, an owner could withdraw access
while a request was pending and still get a session, and automation could target the screens
that edit automation grants. The locking design avoids a cycle with WindowManager:
`ActivityClientController.java:1966` takes `mGlobalLock` for Back handling and reaches
`isOnComputerControlDisplay` at `:1994`. Nothing that queries other services, mutates grants,
closes sessions or calls clients runs while `mSessions` is held.

**Security argument.** Automation cannot be used to raise its own access. Withdrawal cannot be
bypassed by a pending request and cannot affect another user's sessions. A concurrent edit
rejects an in-progress creation even if it concerns another user, which is conservative.

**Leaves alone.** Debug super agents and shell or test-only agents that were authorized at
request time.

**Files.** `ComputerControlAllowlistController.java`, `ComputerControlUserAllowlist.java`,
`ComputerControlSessionProcessor.java`, `ComputerControlSessionImpl.java` and three test files.

**Tests.** `ComputerControlSessionProcessorTest`, `ComputerControlAllowlistControllerTest`,
`ComputerControlUserAllowlistTest`, including concurrent registry access.

**Rebase risk.** High. This patch rewrites the creation path of `ComputerControlSessionProcessor`
and is the most likely to conflict when AOSP changes that class. The protected package names
match this tree. A rebase that renames Settings or the consent app must update both this patch
and Settings 0001.

### 0004 `computercontrol: validate parcelled session parameters at the service boundary`

**Changes.** The service enforces the session version, the notification and its nested
content, the target count limit and attribution, whether or not the caller used the Builder.

**Why.** Parameters arrive over binder and can be written by hand with `Parcel`, skipping every
client-side check.

**Security argument.** The service no longer trusts client-side validation.

**Files.** `ComputerControlSessionProcessor.java` and its test.

**Tests.** Crafted-Parcel regression cases. Supported-version fixtures updated.

**Rebase risk.** Moderate.

### 0005 `computercontrol: recheck caller permissions and policy before publishing a session`

**Changes.** Using the captured UID, package and user, the service rechecks before construction
and again before publication: the assistant role, the notification and Computer Control
permissions, managed-device policy and the Computer Control AppOp.

**Why.** Any of these can change while the consent dialog is open or the session is being built.

**Security argument.** "Allow once" cannot override an explicit AppOp denial. A normal agent
that loses its permission is not reclassified as a test agent. These checks read several
services and are not one transaction. They run at both points, and existing runtime watchers
still apply after publication.

**Files.** `ComputerControlSessionProcessor.java`, `ComputerControlAllowlistController.java` and
their tests.

**Rebase risk.** Moderate.

## 6. packages/apps/Settings

### 0001 `Screen automation: let the user allow agents and target apps`

**Changes.**
- Special app access > Screen automation lists every app that holds `ACCESS_COMPUTER_CONTROL`,
  not only already-approved ones. Unallowed apps read "Not allowed".
- Agent page: main switch "Allow screen automation", off by default. The target list below it is
  disabled while the switch is off, or while the app is not the default assistant.
- App info > Screen automation appears for every launchable app that is not an agent. Its page
  has a main switch "Allow screen automation of this app", off by default. The footer says an
  assistant still needs approval, that turning the switch off clears earlier approvals, and that
  device policy may also allow automation.
- Settings and the consent app get no App info entry, and their direct target page is hidden.
- New strings in `res/values/strings_computer_control_ext.xml`, not GrapheneOS's `strings_ext.xml`.

**Why.** The owner needs one place per app to say yes or no. AOSP already ships these pages
for per-target consent. They only needed a switch above them.

**Security argument.** Off by default on both sides. Neither switch grants access alone.

**Files.** `ComputerControlAgentPageProvider.kt`, `ComputerControlAutomation.kt`,
`ComputerControlTargetAppPageProvider.kt`, the strings file and two robotests.

**Tests.** `SettingsRoboTests:ComputerControlAgentPageProviderTest` and
`SettingsRoboTests:ComputerControlAutomationTest`.

**Rebase risk.** Moderate. SPA page providers change between releases.

## 7. Not in this series

- **User-installed assistants.** The permission stays privileged. See the
  [FAQ](faq.md#can-a-user-installed-assistant-use-this).
- **AppFunctions.** A separate service with a separate allowlist mechanism, which fails open
  when no provider is configured (§8.5). A caller gate is designed but not written.
- **Session limits.** One concurrent session and six targets per session stay hardcoded.
- **What an agent may do inside an allowed app.** Sending, paying and deleting are for the
  assistant's own policy. The OS gate decides only whether the agent may operate the app at all.

## 8. Verified facts

Checked in source at GrapheneOS tag `2026110200`. Line numbers are at the tag, before the
patches. Paths are in frameworks/base unless stated.

### 8.1 Flags and release config
- Declared in `core/java/android/companion/virtual/flags/flags.aconfig`: `computer_control_access`
  :91, `computer_control_per_app_consent` :233, `computer_control_role_assistant_requirement`
  :271, `computer_control_support_v5` :291. None is `is_fixed_read_only`.
- build/release: `release_configs/cur.textproto` inherits `aosp_current`, which
  `release_config_map.textproto` aliases to `cp2a`. `cp2a` inherits `mainline_2026_04` and `cp1a`.
- `aconfig/cp2a/android.companion.virtualdevice.flags/` enables `computer_control_` +
  `activity_policy_strict`, `config_change_override`, `consent`, `managed_profiles`,
  `role_assistant_requirement` and `user_restriction`, all READ_ONLY. It has no file for
  `access`, `per_app_consent` or `support_v5`, so they are disabled. They are read-only because
  `RELEASE_ACONFIG_FLAG_DEFAULT_PERMISSION` is READ_ONLY and `RELEASE_ACONFIG_REQUIRE_ALL_READ_ONLY`
  is true (`flag_values/bp1a/`). Only `aconfig/trunk_staging/` enables them.
- `RELEASE_PACKAGE_COMPUTER_CONTROL` is set true only in `flag_values/trunk_staging/`. build/make
  `target/product/media_system.mk:48-49` adds `VirtualDeviceManager` when it is true.
- `core/res/AndroidManifest.xml:9586`: `ACCESS_COMPUTER_CONTROL` is `internal|privileged`.
  `:9592`: `MANAGE_COMPUTER_CONTROL_CONSENT` is `signature`.
- `VirtualDeviceManagerService.java:590-592` throws when `computer_control_access` is off.

### 8.2 Which allowlist is live
- `ComputerControlAllowlistController.java`: namespace `computer_control` :85; keys
  `allowed_session_owner_apps` :87, `allowed_automatable_apps` :89, `blocked_automatable_apps`
  :91; read with `DeviceConfig.getString` :862; fallback files :80-83 under
  `/data/system/computercontrol/`.
- Agent check `isPackageApprovedToRunAutomation` :283. Target check
  `isPackageInAutomatableAppList` :400. Called from `ComputerControlSessionProcessor.java` :249
  and :275, and from `ComputerControlSessionImpl.java:655` in `launchApplication`.
- `core/java/android/os/allowlist/AllowlistManager.java` declares Computer Control IDs 3 to 5,
  but nothing under `services/companion` uses `AllowlistManager`. The live path is DeviceConfig
  and files.

### 8.3 Enforcement at the tag
- `isPackageAllowedToCreateSession` :211: the caller uid must own the package; super agents only
  on debuggable builds, from an empty resource; requires `ACCESS_COMPUTER_CONTROL` and
  `POST_NOTIFICATIONS`; a uid without the permission must be `testOnly`; assistant role via
  `RoleManager`; then the DeviceConfig agent allowlist.
- Per-app consent: `ComputerControlSessionProcessor.java:181` notes `OP_COMPUTER_CONTROL`. Ignored
  or errored means denied. Allowed means the saved per-agent, per-target store
  (`ComputerControlDataStore.java`, `/data/system_de/0/computercontrol/automatable_apps.xml`).
  Targets without consent go to the consent dialog.
- Settings already ships `ComputerControl{Automation,AgentPageProvider,TargetAppPageProvider}.kt`,
  gated on the flags.

### 8.4 SELinux
- `system/sepolicy` `private/system_server.te:554` allows `system_server` read-write on
  `uhid_device`, and `private/file_contexts:218` labels `/dev/uinput` as `uhid_device`. Same in
  AOSP `android17-release`.
- `system/core` `rootdir/ueventd.rc:67` makes `/dev/uinput` `0660 uhid uhid`. `system_server`'s
  groups include AID_UHID (`ZygoteInit.java:754`).
- The device is opened in `system_server` (`VirtualInputDeviceController.java:217`), not by the
  agent. No sepolicy change is needed.

### 8.5 AppFunctions
- `services/appfunctions/.../CallerValidatorImpl.java:117-130` uses
  `SystemAppFunctionAllowlistReader.java:126`, `AllowlistManager` ID 2.
- `SystemAppFunctionAllowlistReader.java:179-183` treats provider, invalid-request and network
  errors as allowlisted. `config_allowlistProviderServicePackage` is empty, so on GrapheneOS
  there is no provider and the check fails open.

## 9. Device checks still to run

Compilation and host tests are recorded in the [validation record](regression-tests.md). These
need a device:

- `dumpsys virtualdevice` shows both owner lists, empty after first boot.
- A request fails with neither switch on and with only the agent switch on. With both, the
  consent dialog appears. After approval the session runs.
- Allow once and Always allow, including a mix of saved and fresh targets.
- Withdrawing an agent, a target, the role, a permission, the AppOp or device-policy eligibility
  while the dialog is open, and during construction. No session may start.
- Withdraw and re-enable a target: its old saved consent is gone, also after a reboot.
- Uninstall and user deletion in a secondary user leave other users' grants intact. The same
  package in two users: withdrawing in one leaves the other's session running.
- Settings and the consent app are rejected even when DeviceConfig lists them.
- Version 4 is rejected. Version 5 sessions require a foreground window and post a notification.
- Malformed requests create no virtual device. Discarded constructions release their device and
  reservation.
- Back pressed on a root activity, racing creation and revocation, does not stall.
- `adb shell cmd device_config put computer_control ...` has no effect.
- No `avc: denied` for `system_server` around `/dev/uinput`.
