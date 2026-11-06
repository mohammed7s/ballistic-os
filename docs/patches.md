# Patch set: user-controlled Computer Control gate

Target: GrapheneOS tag `2026110200` (Android 17). Five patches in three repositories. They turn on
Android 17's Computer Control and add a per-user allowlist that only the owner edits, next to the
DeviceConfig allowlists that GrapheneOS never receives. Nothing is removed or replaced.

The patches are in `patches/`; `patches/README.md` gives the apply order and commands. Design
context: `ballistic/docs/CONTEXT.md` §4b–4c and `ballistic/docs/PLAN.md` step 5.

Status: written, applied with `git am` to fresh clones of the tag, diff identical to the work
branch, `git diff --check` clean. **Not compiled and not run.** The checklist at the end lists
what only a build and a device can confirm.

## 1. Summary for a reviewer

- Computer Control is AOSP code already in GrapheneOS. It is unreachable because two aconfig flags
  are off in the release config, and because the apps allowed to use it come from DeviceConfig
  (Google's remote config), which GrapheneOS does not receive.
- These patches turn the flags on, include the AOSP consent dialog app, and add a second source
  for the allowlists: two per-user lists, empty by default, edited only through Settings.
- Every existing check stays and runs in the same order: privileged permission, notifications
  permission, assistant role, allowlist, app-op, per-target consent dialog. The user lists are
  ORed into the one allowlist step; nothing else changes.
- No change to GrapheneOS hardening, sepolicy, keystore, verified boot, attestation, or
  GosPackageState.

## 2. The patches

| # | Repo (path in tree) | File | Subject | Size |
|---|---|---|---|---|
| 1 | `platform_build_release` (`build/release`) | `0001-computer-control-flags.patch` | cp2a: enable Computer Control and its per-app consent | 2 files, +12 |
| 2 | `platform_build_release` (`build/release`) | `0002-computer-control-consent-app.patch` | cur: include the Computer Control consent app | 1 file, +4 |
| 3 | `platform_frameworks_base` (`frameworks/base`) | `0001-computer-control-user-allowlist.patch` | computercontrol: consult a user allowlist next to DeviceConfig | 4 files, +616 −5 |
| 4 | `platform_frameworks_base` (`frameworks/base`) | `0002-computer-control-user-allowlist-api.patch` | computercontrol: let the user manage the user allowlist | 5 files, +225 |
| 5 | `platform_packages_apps_Settings` (`packages/apps/Settings`) | `0001-computer-control-user-allowlist-ui.patch` | Screen automation: let the user allow agents and target apps | 6 files, +197 −16 |

No `system/sepolicy` patch is needed (§3.3).

### Patch 1: enable the two flags (build/release)

**Changes.** Adds two value files under
`aconfig/cp2a/android.companion.virtualdevice.flags/`: `computer_control_access` and
`computer_control_per_app_consent`, both `ENABLED`, `READ_ONLY`, like the six Computer Control
flags already enabled there.

**Why.** Without `computer_control_access` the `ACCESS_COMPUTER_CONTROL` permission is not defined
and the service throws on every session request. Without `computer_control_per_app_consent` the
`MANAGE_COMPUTER_CONTROL_CONSENT` permission, the per-target consent store and the Settings pages
do not exist.

**Privacy argument.** This only makes the feature reachable. With patches 3–5 no app can use it
until the owner switches on both an agent and a target in Settings, and the agent must also be the
default digital assistant (`computer_control_role_assistant_requirement` is already ENABLED in
cp2a). READ_ONLY means no runtime override.

**Untouched.** `computer_control_support_v5` stays DISABLED (inference: not needed for the
Android 17 session API this uses). No other flag changes.

### Patch 2: include the consent dialog app (build/release)

**Changes.** Adds `flag_values/cur/RELEASE_PACKAGE_COMPUTER_CONTROL.textproto` = true. build/make
then adds `VirtualDeviceManager` to `PRODUCT_PACKAGES`.

**Why.** Session creation with per-app consent sends the user to a dialog
(`ACTION_REQUEST_ACCESS`) for any target the agent has not been approved for. The dialog lives in
`frameworks/base/packages/VirtualDeviceManager`, which is only built when this flag is set. Without
it a request can never be approved.

**Privacy argument.** It is the AOSP dialog, platform-signed. It hides non-system overlays and
filters obscured touches. Inference: it runs on the default display, where the agent's session
cannot inject input (the session injects only into its own virtual display).

**Untouched.** The dialog's code and behaviour.

### Patch 3: the user allowlist (frameworks/base, services)

**Changes.**
- New `ComputerControlUserAllowlist` (services/companion, package
  `com.android.server.companion.virtual.computercontrol`): two lists, session owners (agents) and
  automatable apps (targets), per user, empty by default.
- Each entry stores the SHA-256 digests of the package's signing certificates at the time the
  user allowed it. Matching uses `SigningDetails.hasAncestorOrSelfWithDigest`: a key rotation with
  the old certificate in its lineage keeps the entry; a package with the same name and a different
  signer does not inherit it.
- Persisted with `AtomicFile` at `/data/system/computercontrol/user_allowlist.xml` (same
  directory as the existing fallback files), loaded once at boot on the background executor,
  written on change. A corrupt or unreadable file reads as empty (fail closed).
- `ComputerControlAllowlistController` consults it with OR at the two existing allowlist points:
  - session owner: `isPackageApprovedToRunAutomation` — `DeviceConfig list || user list`;
  - target: `isPackageInAutomatableAppList` — a user-approved agent is rejected as a target (same
    as a DeviceConfig-approved one), the DeviceConfig denylist is still checked first and still
    wins, then `DeviceConfig list || user list`.
- Entries are dropped when the package is removed for that user (hooked into the existing
  package-removed handler).
- `dumpsys virtualdevice` prints both lists.
- Controller methods `is/setPackageApprovedToRunAutomationByUser` and
  `is/setPackageTargetableForAutomationByUser` (used by patch 4). Setting resolves the package's
  current signing details; unknown package → `IllegalArgumentException`.
- Unit test `tests/VirtualDeviceTests/services/.../ComputerControlUserAllowlistTest.java`: empty by
  default, signer and user binding, roles kept separate, key rotation, removal, package removal per
  user, persistence round-trip, corrupt file.

**Why.** On GrapheneOS the DeviceConfig lists are always empty, so no app can ever own a session or
be a target. Replacing the DeviceConfig lookup would conflict with every upstream change to it and
take the vendor path away from devices that use it; adding a second source does neither.

**Privacy argument.** Default empty. Only the user can add (patch 4 requires a signature
permission; Settings is the only UI). Bound to signers, so reinstalling a different app under the
same name cannot reuse a grant. Fail closed on corrupt storage. Per user, so a secondary user's
choices do not leak into another. Everything that gated a session before still gates it.

**Untouched.** DeviceConfig path and fallback files, the denylist, test-only agents, super agents
(debuggable builds only), assistant role check, app-op and per-target consent store, the consent
dialog, `MAXIMUM_CONCURRENT_SESSIONS`, `MAX_TARGET_PACKAGES`.

### Patch 4: binder API for the user allowlist (frameworks/base, core + services)

**Changes.** Four methods on `IComputerControlConsentManager` (AIDL), the
`ComputerControlConsentManager` interface and its client in `VirtualDeviceManager`, implemented in
`VirtualDeviceManagerService` and `ComputerControlSessionProcessor`:
`isPackageApprovedToRunAutomationByUser`, `setPackageApprovedToRunAutomationByUser`,
`isPackageTargetableForAutomationByUser`, `setPackageTargetableForAutomationByUser`.
- `@EnforcePermission(MANAGE_COMPUTER_CONTROL_CONSENT)` (signature level; inference: held by
  Settings and the consent app, which are platform-signed); acting on another user also needs
  `INTERACT_ACROSS_USERS_FULL`.
- No-ops (return false / do nothing) while `computer_control_access` is off.
- Withdrawing an agent closes its sessions; withdrawing a target closes any session automating it
  (`CLOSE_REASON_USER_INITIATED`), the same loop the existing per-agent consent removal uses.
- The `...ByUser` getters report the user list only, not DeviceConfig, so the Settings switch shows
  exactly what the user chose.

**Why.** Settings needs a way to edit the lists; the consent manager interface is where the
existing per-agent consent methods already live, behind the same permission.

**Privacy argument.** No new permission, no new caller class. The API is `@hide`. An agent cannot
approve itself: it would need a signature permission. Revocation takes effect on live sessions,
not only the next one.

**Untouched.** Existing consent-manager methods and their semantics.

### Patch 5: Settings UI (packages/apps/Settings)

**Changes.**
- Special app access → Screen automation lists every app that holds `ACCESS_COMPUTER_CONTROL`
  (`hasGrantPermission`; the permission is privileged, so only preinstalled, allowlisted apps), not
  only already-approved ones. Unapproved apps read "Not allowed".
- Agent page: main switch "Allow screen automation", off by default. The per-target list below it
  is disabled while the switch is off (or while the app is not the default assistant, as before).
- App info → Screen automation is shown for every launchable app that does not request
  `ACCESS_COMPUTER_CONTROL`. Its page has a main switch "Allow screen automation of this app", off
  by default, and a footer explaining that an assistant still needs approval. The entry is now
  always clickable; its summary is "Not allowed" until the switch is on.
- New strings in `res/values/strings_computer_control_ext.xml`.
- Robotests updated: `ComputerControlAgentPageProviderTest`, `ComputerControlAutomationTest`.

**Why.** The owner needs one place per app to say yes or no; AOSP's pages already exist for the
per-target consent and only needed the switch above them.

**Privacy argument.** Off by default on both sides. Both switches open a gate; neither grants
access alone (§4).

**Untouched.** The AOSP pages' existing content, GrapheneOS's `strings_ext.xml`.

## 3. Verified facts

All checked in source at GrapheneOS tag `2026110200` (line numbers are at the tag, before the
patches). frameworks/base paths unless stated.

### 3.1 Flags and release config (why patches 1 and 2)
- Flags declared in `core/java/android/companion/virtual/flags/flags.aconfig`:
  `computer_control_access` :91, `computer_control_per_app_consent` :233,
  `computer_control_role_assistant_requirement` :271, `computer_control_support_v5` :291. None is
  `is_fixed_read_only`.
- build/release: `release_configs/cur.textproto` is `inherits: "aosp_current"`;
  `release_config_map.textproto` aliases `aosp_current` → `cp2a`; `release_configs/cp2a.textproto`
  inherits `mainline_2026_04` and `cp1a` and uses value set
  `aconfig_value_set-platform_build_release-cp2a` (`aconfig/cp2a/*/Android.bp`).
- `aconfig/cp2a/android.companion.virtualdevice.flags/` has value files for
  `computer_control_{activity_policy_strict, config_change_override, consent, managed_profiles,
  role_assistant_requirement, user_restriction}`, all ENABLED/READ_ONLY; `computer_control_typing`
  is ENABLED in cp1a. There is **no file** for `computer_control_access`,
  `computer_control_per_app_consent` or `computer_control_support_v5`, so they are DISABLED; and
  READ_ONLY because `RELEASE_ACONFIG_FLAG_DEFAULT_PERMISSION` = READ_ONLY (`flag_values/bp1a/`) and
  `RELEASE_ACONFIG_REQUIRE_ALL_READ_ONLY` = true (bp1a). Only `aconfig/trunk_staging/` enables them.
- `RELEASE_PACKAGE_COMPUTER_CONTROL` is declared in
  `flag_declarations/RELEASE_PACKAGE_COMPUTER_CONTROL.textproto` and set true only in
  `flag_values/trunk_staging/`; build/make `target/product/media_system.mk:48-49` adds
  `VirtualDeviceManager` when it is true.
- Consent app: `packages/VirtualDeviceManager`, platform certificate, handles
  `android.companion.virtual.computercontrol.action.REQUEST_ACCESS`;
  `RequestComputerControlAccessActivity.java:46` adds `SYSTEM_FLAG_HIDE_NON_SYSTEM_OVERLAY_WINDOWS`;
  `res/values/themes.xml:45,62` set `filterTouchesWhenObscured`.
- GrapheneOS's own build-flag values are in build/release `flag_values/cur/` (kernel directories
  for every Pixel). **Inference:** GrapheneOS builds release `cur`, so patch 2 belongs there.
- `core/res/AndroidManifest.xml:9586` `ACCESS_COMPUTER_CONTROL` internal|privileged, featureFlag
  `computer_control_access`; `:9592` `MANAGE_COMPUTER_CONTROL_CONSENT` signature, featureFlag
  `computer_control_per_app_consent`.
- `services/companion/.../VirtualDeviceManagerService.java:590-592` throws
  `IllegalStateException("... flag disabled")` when `computer_control_access` is off.

### 3.2 Which allowlist is live (why patch 3 hooks where it does)
- `services/companion/java/com/android/server/companion/virtual/computercontrol/ComputerControlAllowlistController.java`:
  namespace `computer_control` :85; keys `allowed_session_owner_apps` :87,
  `allowed_automatable_apps` :89, `blocked_automatable_apps` :91; read with
  `DeviceConfig.getString` :862; fallback files :80-83 under `/data/system/computercontrol/`.
- Session-owner check `isPackageApprovedToRunAutomation` :283, list match :296. Target check
  `isPackageInAutomatableAppList` :400, list match :424. Called from
  `ComputerControlSessionProcessor.java` :249 and :275 (inside `validateRequest` :237) and
  `ComputerControlSessionImpl.java:655` (`launchApplication`).
- `core/java/android/os/allowlist/AllowlistManager.java` declares Computer Control IDs 3–5 (:64,
  :69, :74), but the only consumer is `services/allowlist/.../AllowlistShellCommand.java:206` (a
  root check). Nothing under `services/companion` references `AllowlistManager`. **The live path is
  DeviceConfig/files.**

### 3.3 Sepolicy (why there is no sepolicy patch)
- GrapheneOS `platform_system_sepolicy/private/system_server.te:554`
  `allow system_server uhid_device:chr_file rw_file_perms;` (`rw_file_perms` includes `ioctl`,
  `public/global_macros:26-32`); `private/file_contexts:218` labels `/dev/uinput` `uhid_device`.
  Identical in AOSP `android17-release`.
- DAC: system/core `rootdir/ueventd.rc:67` `/dev/uinput 0660 uhid uhid`; AID_UHID = 3011;
  system_server's group list in `core/java/com/android/internal/os/ZygoteInit.java:754` includes
  3011.
- The open happens in system_server: `VirtualInputDeviceController.java:217` → native
  `VirtualInputDevice.cpp:240` `open("/dev/uinput")`.

### 3.4 Enforcement at the tag (what the patches sit inside)
- `isPackageAllowedToCreateSession` :211: caller uid must own the package (:222); super agents only
  on debuggable builds (:656, resource `config_computerControlKnownSuperAgents`,
  `core/res/res/values/config.xml:7593`, empty); requires `ACCESS_COMPUTER_CONTROL` and
  `POST_NOTIFICATIONS` (:233-236); a uid without the permission granted must be `testOnly`
  (:238-253); assistant role via `RoleManager` (:255-273, flag ENABLED in cp2a); then the
  DeviceConfig session-owner allowlist (:275).
- Per-app consent: `ComputerControlSessionProcessor.java:181` `noteOp(OP_COMPUTER_CONTROL)`;
  MODE_IGNORED/ERRORED → denied (:185); MODE_ALLOWED → per-agent-per-target store
  `doesAgentHaveConsentToAutomateTargetApp` (:435), persisted by `ComputerControlDataStore.java` in
  `/data/system_de/0/computercontrol/automatable_apps.xml` (:50, :64); targets without consent →
  consent dialog intent `ACTION_REQUEST_ACCESS` (:216).
- Settings already ships the pages:
  `src/com/android/settings/spa/app/specialaccess/ComputerControl{Automation,AgentPageProvider,TargetAppPageProvider,AutomationPreferenceController}.kt`,
  wired in `res/xml/special_access.xml:33` and `spa/app/appinfo/AppInfoSettings.kt:207,215`,
  gated on the flags.

## 4. The layered check

A session request from app A to automate target T passes every box, in this order. Boxes marked
`[new]` are where the patches add a source; nothing is removed.

```
build time   A is a priv-app with ACCESS_COMPUTER_CONTROL in its privapp-permissions allowlist
                 (patch 1 makes the permission exist; image builder decides who gets it)
                                         |
session      caller uid owns A; A holds ACCESS_COMPUTER_CONTROL and POST_NOTIFICATIONS
creation     A holds ROLE_ASSISTANT (default digital assistant)
                                         |
             session owner allowed:  DeviceConfig list  OR  [new] user list "Allow screen automation"
                                         |
per target   T is not an approved agent (DeviceConfig or [new] user list)
             T is not on the DeviceConfig denylist
             T allowed:  DeviceConfig list  OR  [new] user list "Allow screen automation of this app"
                                         |
             app-op COMPUTER_CONTROL for A: ignored/errored -> deny
             per-agent consent store has (A, T)?  no -> AOSP consent dialog (patch 2), user approves
                                         |
             session runs on its own virtual display; launchApplication(T) re-checks the target
```

On GrapheneOS the DeviceConfig lists are always empty, so the user lists are the only way through.

Revocation: switching off A's switch closes A's sessions; switching off T's switch closes every
session automating T; removing (A, T) consent closes A's sessions on T (AOSP behaviour); uninstall
drops the user-list entries for that user.

## 5. What the user sees

1. Out of the box: Settings → Apps → Special app access → Screen automation lists the preinstalled
   apps that hold the permission (in a Ballistic build, the Ballistic assistant), each "Not
   allowed". Every app's App info has a Screen automation entry reading "Not allowed".
2. The owner opens the assistant's page and turns on "Allow screen automation". If the assistant
   is not the default digital assistant, its target list stays disabled, as in AOSP.
3. The owner opens App info → Screen automation for, say, a notes app and turns on "Allow screen
   automation of this app". The footer says an assistant still needs approval.
4. The first time the assistant asks to automate that app, the AOSP consent dialog appears; the
   owner approves. Afterwards the agent's page lists the approved targets and they
   can be removed one by one.
5. Turning either switch off ends running sessions at once.

There is no global switch: with no app allowed, the feature is off.

## 6. Decision log

- **Option A: agent switch + target switch + AOSP consent dialog** (owner confirmed, 7 Nov 2026).
  Two switches mean a newly installed app is never automatable by default and a preinstalled
  agent does nothing until the owner says so; the dialog keeps the per-pair decision AOSP already
  designed.
- **No master switch.** AOSP has none; per-app lists empty by default already mean "off", and a
  master switch would be one more state to keep consistent across users.
- **Delta, not replacement.** DeviceConfig lookup kept intact so upstream changes rebase cleanly
  and the patch is acceptable on devices that do use DeviceConfig.
- **No GosPackageState / app-switch framework.** Stays AOSP-shaped, needs no GrapheneOS-specific
  flag numbers (which would conflict as GrapheneOS adds its own), and is reviewable by someone who
  knows AOSP's Computer Control but not GrapheneOS internals.
- **Own strings file** (`strings_computer_control_ext.xml`), not GrapheneOS's `strings_ext.xml`,
  to avoid rebase conflicts.
- **Signer-bound entries** rather than package names, so a grant cannot be inherited by a
  different app reusing the name.
- **No per-action granularity at OS level.** What the agent may do inside an allowed app (send,
  pay, delete) is the Ballistic app's policy (`ballistic/SPEC.md` §4.3), enforced in the app with a
  fingerprint confirmation the agent cannot press.
- **No sepolicy change**, because none is needed (§3.3).

## 7. AppFunctions caller gate (design only, not implemented)

The Computer Control store does not cover AppFunctions: different service, different allowlist
mechanism. Verified at the tag:
- `services/appfunctions/.../CallerValidatorImpl.java:117-130` →
  `allowlist/SystemAppFunctionAllowlistReader.java:126`, which uses `AllowlistManager` ID 2.
- `SystemAppFunctionAllowlistReader.java:179-183` treats `ERROR_PROVIDER`, `INVALID_REQUEST` and
  `NETWORK` as allowlisted, i.e. **fails open**; `config_allowlistProviderServicePackage` is empty
  (`core/res/res/values/config.xml:8039`), so on GrapheneOS there is no provider.
- `enable_app_function_permission_v2` is ENABLED in cp2a. `EXECUTE_APP_FUNCTIONS` is `normal` when
  `app_function_access_api_enabled` (`AndroidManifest.xml:9547-9549`), otherwise
  internal|privileged (`:9568-9570`). The cp2a value of `app_function_access_api_enabled` was not
  checked.

Proposed delta (a future patch pair):
1. A per-user caller allowlist with the same shape as `ComputerControlUserAllowlist` (signer-bound,
   default empty, fail closed, dropped on uninstall), in services/appfunctions.
2. Consult it in `SystemAppFunctionAllowlistReader` (or a local `AppFunctionAllowlistReader`) as an
   OR next to the provider result.
3. Make the no-provider branch fail closed: when no allowlist provider is configured, an error is
   "not allowlisted" unless the user list says otherwise. Devices with a provider keep today's
   behaviour.
4. Binder methods behind the existing AppFunctions management permission, and a Settings switch on
   the caller app's page.

Before writing it: check `app_function_access_api_enabled` in cp2a, and whether the user-approval
flags in `AppFunctionAccessService.kt` are checked on the execute path.

## 8. First-build verification checklist

Not verifiable without a build or a device:

**Build**
- [ ] All three repos compile; NullAway/errorprone pass in `services.companion` (its Android.bp
      sets `-Xep:NullAway:ERROR`).
- [ ] AIDL `@EnforcePermission` generates `*_enforcePermission()` for the four new methods.
- [ ] `@UserIdInt` import present in `VirtualDeviceManagerService` (it is at :33 at the tag).
- [ ] GrapheneOS actually builds release `cur` for blazer (inference from `flag_values/cur`), so
      patch 2 takes effect and `VirtualDeviceManager` is in the image.
- [ ] The cp2a value-set additions are picked up (glob `*_flag_values.textproto`); check the
      generated aconfig values for both flags.
- [ ] Settings: `MainSwitchPreference` renders inside `RegularScaffold` and in the AppList header;
      the `isValidAgent` change does not hide pages; ktfmt/import order in the two robotests.
- [ ] Cost of the App info entry on every launchable app is acceptable (`getAgentsForTarget`
      iterates installed apps).

**Tests**
- [ ] `atest ComputerControlUserAllowlistTest ComputerControlAllowlistControllerTest`.
- [ ] Settings robotests `ComputerControlAgentPageProviderTest`, `ComputerControlAutomationTest`.

**Device**
- [ ] `dumpsys virtualdevice` shows both user lists, empty after first boot.
- [ ] A session request with neither switch on fails; with the agent switch only fails; with both
      it shows the consent dialog; after approval the session runs.
- [ ] Turning either switch off closes a live session.
- [ ] Uninstall of a target removes its entry.
- [ ] `adb shell cmd device_config put computer_control ...` has no effect (expected on
      GrapheneOS).
- [ ] No `avc: denied` for system_server around `/dev/uinput` (`logcat | grep avc`).

**Ballistic app (later step, README item 4)**
- [ ] Shipped as a priv-app with `ACCESS_COMPUTER_CONTROL` in a privapp-permissions allowlist,
      `POST_NOTIFICATIONS` granted, set as default digital assistant.

## 9. Review follow-up (7 November 2026; design before implementation)

Three additive commits follow the original series:

- **frameworks/base: revocation and lifecycle hardening.** Deny Settings and the bundled
  consent app as automation targets before any bypass; clear all agents' consent for a target
  in the affected user when its switch is withdrawn; receive uninstall broadcasts for all users
  and remove both stores' records when a user is deleted. Recheck owner/target eligibility and
  consent immediately before asynchronous session creation. Serialize creation with consent and
  user-list edits, and scope session closures to the affected user. Require version 5 so the
  Android 17 foreground-window check cannot be avoided by requesting version 4. Files: allowlist
  controller, user store, session processor and implementation, and focused regression tests.
  Privacy: permission editors cannot grant more access through automation; withdrawal cannot be
  bypassed by an already-pending request or affect another user's sessions.
- **build/release: enable version 5 support** in cp2a alongside the existing access/consent flags.
  File: the corresponding aconfig value. Otherwise requiring v5 would leave the advertised
  server version at 4. No permission, role or per-target consent relaxation.
- **Settings: correct the target-switch footer and hide protected targets.** Files:
  `strings_computer_control_ext.xml`, `ComputerControlTargetAppPageProvider.kt`. Hide both the
  App info entry and direct target-page route for Settings and the consent app.
  The user list is an additional source beside DeviceConfig, so off is not a universal deny.
  The footer must describe user approval and retained device policy accurately.

DeviceConfig, signing checks, GrapheneOS hardening, sepolicy, keystore, verified boot and
attestation remain intact. SPEC and README will describe the additive gate and privileged-app
requirement. Compile and device results remain pending the build agent's unmodified build.

The creation recheck preserves "Allow once": only the targets approved by the current dialog
bypass the saved-consent lookup. Targets previously approved with "Always allow" are checked
again in the persisted store. Verified source: frameworks/base
`packages/VirtualDeviceManager/src/com/android/virtualdevicemanager/RequestComputerControlAccessFragment.java:183-212`.

Follow-up first-build checks (not executed on this laptop):
- [ ] Run `VirtualDeviceServicesTests` tests for `ComputerControlUserAllowlistTest`,
      `ComputerControlAllowlistControllerTest` and `ComputerControlSessionProcessorTest`.
- [ ] Check both "Allow once" and "Always allow", including mixed targets with saved and fresh
      consent. Withdraw an owner or target while its dialog is open; no session should start.
- [ ] Withdraw then re-enable a target; its old saved consent must be gone, including after reboot.
- [ ] Repeat uninstall and user deletion in a secondary user; other users' grants must survive.
- [ ] With identical package names installed in two users, withdrawing in one must not close the
      other's session. Exercise creation/revocation concurrently to check locking and deadlocks.
- [ ] Settings and the consent app must be rejected even if present in DeviceConfig; their target
      settings entries and direct routes must be hidden.
- [ ] Version 4 must be rejected; version 5 must be advertised and require a foreground window.

The protected package names match this pinned tree. A future rebase that renames Settings or the
consent app must update both the service denial and the Settings UI exclusion.

Verification performed on 7 November 2026: all eight patches applied with `git am` to new
`--depth 1 --branch 2026110200` clones from the local source repositories. Each resulting Git tree
exactly matched its implementation clone. `git diff --check` passed for all three series;
the edited Settings strings parsed as XML. These checks do not establish compilation or runtime
correctness. Verification checkout: `~/src/ballistic-os-work/verify/followup-uf1zhxud/`.
