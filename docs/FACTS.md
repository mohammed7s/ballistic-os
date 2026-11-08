# OS source research

Preserved from Ballistic CONTEXT §4c, checked against the pinned source tag on 7 November 2026. Build-status statements below describe the research session, not the latest validation. See [current context](CONTEXT.md) and [validation](regression-tests.md). Original § references refer to the [historical handoff](https://github.com/mohammed7s/ballistic/blob/master/docs/log/2026-11-07-before-reorganization-context.md).

## Computer Control gate
 source answers and patch set (7 Nov 2026)

All **verified** at GrapheneOS tag `2026110200` (line numbers at the tag; frameworks/base unless
stated). Inferences are labelled. The patch set built on these answers is in
`ballistic-os/patches/` (eleven patches: build/release ×3, frameworks/base ×6, packages/apps/Settings
×2), applied with `git am` to fresh clones; **not compiled or run yet**. Design and first-build
checklist: `ballistic-os/docs/patches.md`. *Superseded 8 Nov 2026:* the series was re-cut into
eight patches with the same final source apart from licence comments; section numbers below
refer to the earlier design document, now
[log/2026-11-07-patch-design-and-review-history.md](log/2026-11-07-patch-design-and-review-history.md).

- **Flags (verified).** `core/java/android/companion/virtual/flags/flags.aconfig`:
  `computer_control_access` :91, `computer_control_per_app_consent` :233,
  `computer_control_role_assistant_requirement` :271, `computer_control_support_v5` :291; none
  fixed-read-only. build/release: `release_configs/cur.textproto` inherits `aosp_current`;
  `release_config_map.textproto` aliases `aosp_current` → `cp2a`; `cp2a` inherits
  `mainline_2026_04` + `cp1a`, value set `aconfig/cp2a/*/Android.bp`. In
  `aconfig/cp2a/android.companion.virtualdevice.flags/` there are files for
  `activity_policy_strict, config_change_override, consent, managed_profiles,
  role_assistant_requirement, user_restriction` (ENABLED/READ_ONLY); `typing` ENABLED in cp1a;
  **none for `access`, `per_app_consent`, `support_v5` → DISABLED**, READ_ONLY via
  `RELEASE_ACONFIG_FLAG_DEFAULT_PERMISSION` and `RELEASE_ACONFIG_REQUIRE_ALL_READ_ONLY`=true (bp1a).
  Only `aconfig/trunk_staging/` enables them. `RELEASE_PACKAGE_COMPUTER_CONTROL`
  (`flag_declarations/`) is true only in `flag_values/trunk_staging/`; build/make
  `target/product/media_system.mk:48-49` adds `VirtualDeviceManager` when set. Consent app
  `packages/VirtualDeviceManager`: platform cert, `ACTION_REQUEST_ACCESS`,
  `RequestComputerControlAccessActivity.java:46` hides non-system overlays, `res/values/themes.xml:45,62`
  `filterTouchesWhenObscured`. Permissions: `core/res/AndroidManifest.xml:9586`
  `ACCESS_COMPUTER_CONTROL` internal|privileged, `:9592` `MANAGE_COMPUTER_CONTROL_CONSENT` signature,
  both featureFlag-gated. `VirtualDeviceManagerService.java:590-592` throws when the flag is off.
  GrapheneOS's own build-flag values are in `flag_values/cur/` (**inference:** GrapheneOS builds
  release `cur`; to confirm on the first patched build).
- **Open question 12 answered (verified): the live allowlist path is DeviceConfig/files, not
  `AllowlistManager`.** `services/companion/.../computercontrol/ComputerControlAllowlistController.java`:
  namespace `computer_control` :85, keys :87/:89/:91, read via `DeviceConfig.getString` :862,
  fallback files :80-83 in `/data/system/computercontrol/`. Owner check
  `isPackageApprovedToRunAutomation` :283 (match :296); target check
  `isPackageInAutomatableAppList` :400 (match :424); called from
  `ComputerControlSessionProcessor.java:249,275` (`validateRequest` :237) and
  `ComputerControlSessionImpl.java:655` (`launchApplication`). `AllowlistManager.java` IDs 3–5
  (:64, :69, :74) are used only by `services/allowlist/.../AllowlistShellCommand.java:206`; nothing
  in `services/companion` references `AllowlistManager`.
- **Open question 11 answered (verified): no sepolicy change needed.** GrapheneOS
  `system/sepolicy/private/system_server.te:554` `allow system_server uhid_device:chr_file
  rw_file_perms;` (includes ioctl, `public/global_macros:26-32`); `private/file_contexts:218`
  labels `/dev/uinput` `uhid_device`; identical in AOSP `android17-release`. DAC: system/core
  `rootdir/ueventd.rc:67` `/dev/uinput 0660 uhid uhid` (AID 3011), and system_server's groups
  (`ZygoteInit.java:754`) include 3011. The open is in system_server
  (`VirtualInputDeviceController.java:217` → `VirtualInputDevice.cpp:240`).
- **Enforcement at the tag (verified).** `isPackageAllowedToCreateSession` :211: uid owns package
  :222; super agents only on debuggable builds (:656, `config_computerControlKnownSuperAgents`
  empty, config.xml:7593); `ACCESS_COMPUTER_CONTROL` + `POST_NOTIFICATIONS` :233-236; non-granted
  uid must be testOnly :238-253; `ROLE_ASSISTANT` :255-273; then DeviceConfig owner list :275.
  Per-app consent: `ComputerControlSessionProcessor.java:181` `noteOp(OP_COMPUTER_CONTROL)`,
  IGNORED/ERRORED → deny :185; ALLOWED → per-agent-per-target store (:435,
  `ComputerControlDataStore.java:50,64`, `/data/system_de/0/computercontrol/automatable_apps.xml`);
  missing targets → consent dialog :216. Settings already ships the Screen automation pages
  (`spa/app/specialaccess/ComputerControl*.kt`, `res/xml/special_access.xml:33`,
  `AppInfoSettings.kt:207,215`), flag-gated.
- **What the patches do.** (1) cp2a value files enabling `computer_control_access` and
  `computer_control_per_app_consent` READ_ONLY; (2) `flag_values/cur/RELEASE_PACKAGE_COMPUTER_CONTROL`
  = true; (3) `ComputerControlUserAllowlist`: per-user agent and target lists, default empty,
  bound to signing-certificate digests (`hasAncestorOrSelfWithDigest`, so key rotation keeps an
  entry and a different signer does not inherit it), `/data/system/computercontrol/user_allowlist.xml`,
  corrupt file → empty, dropped on uninstall, shown in `dumpsys virtualdevice`, ORed in at :296 and
  :424 (an approved agent is never a target; the DeviceConfig denylist still wins); (4) four
  `IComputerControlConsentManager` methods behind `MANAGE_COMPUTER_CONTROL_CONSENT`
  (+`INTERACT_ACROSS_USERS_FULL` cross-user), no-ops while the flag is off, revoking closes
  dependent sessions; (5) Settings: agent page switch "Allow screen automation", App info switch
  "Allow screen automation of this app", both off by default, strings in
  `res/values/strings_computer_control_ext.xml`. Untouched: GrapheneOS hardening, GosPackageState,
  keystore, verified boot, attestation, sepolicy.
- **Review follow-up (7 Nov 2026; source verified, not built).** Three additional commits enable
  and require version 5, protect Settings/consent UI, clear a withdrawn target's saved consent,
  clean both stores on user deletion, receive uninstall broadcasts for every user, and scope
  session closures by user. The original shared construction/edit lock is superseded by the
  second review fixes below. The final asynchronous check uses the request's user.
  In the first-review frameworks/base tree (`28e9047c4`), `services/companion/.../computercontrol/`:
  `ComputerControlAllowlistController.java:215,239,519,651,657,694`,
  `ComputerControlSessionProcessor.java:491`, `ComputerControlUserAllowlist.java:144`.
  **Verified at the tag:** `core/java/android/companion/virtual/VirtualDeviceManager.java:140`
  advertises 5 only with `computerControlSupportV5`; `ComputerControlSessionParams.java:41`
  defines the Android 17 minimum as 5. `packages/VirtualDeviceManager/src/com/android/virtualdevicemanager/RequestComputerControlAccessFragment.java:183-212`
  distinguishes one-time consent (RESULT_OK only) from persistent consent. The recheck retains
  one-time approval for the targets in the current dialog. Regression tests added; execution,
  compilation and device race checks remain on the first-build checklist. Settings footer and
  SPEC now explicitly describe an additional allowlist, not an off switch for DeviceConfig.
- **Second review fixes (7 Nov 2026; source verified, not built).** frameworks/base patches
  0004–0006 replace the creation lock with a pending reservation and authorization generation;
  construction, policy queries, store mutation and session closure occur outside `mSessions`.
  Incoming Parcel parameters are checked server-side, including notification content and the
  six-target limit. Permission, role, AppOp and device-policy checks run before construction and
  immediately before publication with the captured identity; one-time consent cannot override
  AppOp denial. Source: patched `ComputerControlSessionProcessor.java:261,501,550,565` and
  `ComputerControlAllowlistController.java:657` under `services/companion/.../computercontrol/`.
  The prior inversion is verified against `services/core/java/com/android/server/wm/ActivityClientController.java:1966,1994`:
  Back holds WindowManager's global lock while querying the session registry. Sixteen regression
  tests added, not executed; build and device stress checks remain in `ballistic-os/docs/patches.md` §10.
  **Application verification (7 Nov 2026):** all eleven patches apply to fresh shallow clones of
  `2026110200`, pass source whitespace checks, and reproduce the implementation trees. Final
  frameworks/base source commit: `3e3376079`; its tree is
  `0ef7ff77cf4ac2f5136fbb246dd45b10a3632922`. This does not establish compilation or runtime safety.
- **AppFunctions (verified; design only).** Does not fall out of the Computer Control store.
  `CallerValidatorImpl.java:117-130` → `SystemAppFunctionAllowlistReader.java:126`
  (`AllowlistManager` ID 2); :179-183 fails open on ERROR_PROVIDER/INVALID_REQUEST/NETWORK;
  `config_allowlistProviderServicePackage` empty (config.xml:8039); `enable_app_function_permission_v2`
  ENABLED in cp2a; `EXECUTE_APP_FUNCTIONS` normal when `app_function_access_api_enabled`
  (`AndroidManifest.xml:9547-9549`) else internal|privileged (:9568-9570); that flag's cp2a value
  not checked. Needs its own delta: a user allowlist consulted in the reader, and fail-closed when
  no provider is configured (`ballistic-os/docs/patches.md` §7).
