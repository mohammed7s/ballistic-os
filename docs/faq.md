# FAQ for reviewers

Short answers to the questions a GrapheneOS maintainer is likely to ask. Patch details are in
the [reviewer guide](patches.md); its §8 has the source references.

This repository covers OS-level permissions only: which assistant may use Computer Control, on
which apps, under the owner's control. How an assistant behaves inside apps, and whether apps
accept it, is outside its scope. The FAQ does record what apps can see, so reviewers know the
patches take no side.

## Why not just enable the flags and use the existing allowlist?

The existing allowlist comes from DeviceConfig, Google's remote configuration, which GrapheneOS
does not receive. Its fallback files under `/data/system/computercontrol/` can only be written
with a computer connection or root. Enabling the flags alone would leave the feature unusable,
or usable only through a developer workflow. The patches add an owner list beside it, edited in
Settings.

## What does this add for someone who never turns it on?

- The Computer Control permissions become defined, and the consent dialog app is installed.
- Settings shows one Screen automation page, with fresh assistant and target grants off.
- `system_server` reads one small, empty owner-list file at boot.
- Five new hidden binder methods exist (owner/target grants and target eligibility), callable only with a signature permission.

On the normal installed-assistant path, neither role selection nor the permission alone can open
a session: both owner switches and target consent are required. Existing privileged vendor-list
paths remain compatible. Fresh owner lists start empty; this recipe selects no assistant.

## What can an allowed assistant do?

Inside the target apps the owner allowed, on a virtual display: launch them, read their
accessibility tree and screenshots of that display, tap, swipe and type. It cannot reach apps
the owner did not allow, Settings or the consent app. Sessions need an unlocked device, and
version 5 sessions need a foreground window and post a notification. One session at a time, at
most six target apps.

That is a lot of power inside an allowed app. A compromised or malicious assistant could read
everything those apps show and act in them. What the assistant does inside an app, such as
confirming before a payment, is the assistant's own policy. The OS gate decides only which
assistant may operate which apps.

## How is this different from an accessibility service?

Android already lets the owner enable an installed accessibility service. That service can read
and act on every app, on the owner's own screen. Computer Control is narrower:

- Access is per target app, through two owner switches and a consent dialog.
- It works on a separate virtual display rather than the owner's screen.
- Settings and the consent app can never be targets.
- The assistant must be the default digital assistant.
- Its input is identifiable, as [a later answer](#can-apps-tell-they-are-being-automated)
  explains.

The patches do not change accessibility services.

## Can a user-installed assistant use this?

The 21 November extension implements this experimentally. A normal independently signed APK can
request `ACCESS_COMPUTER_CONTROL`, qualify as an assistant and receive the permission when the
owner selects it through system Default apps settings. The permission is `internal|privileged|role`;
the original privileged path remains. An ordinary app cannot grant itself the role permission.

The owner then uses one centralized **Screen automation** Settings page: the selected assistant
and its switch, plus a searchable eligible target list with inline switches. Fresh grants all start
off, and system per-target consent remains separate. Ordinary assistants require both owner gates
even if DeviceConfig also lists them. No preinstall, platform signature, root, `pm grant` or
production test bypass is required by this design.

The installed shared wrapper, public compile-only stubs, minimal ordinary fixtures and exact flow
are in the [integration contract](assistant-integration.md). Clean patch application and a public-SDK
Java signature/fixture contract check passed. Full-tree compilation, APK packaging and device
execution of this extension are not run, so normal installation and session success are not yet
runtime-proven.

At this pin, assistant-role selection is not in EnhancedConfirmationService's restricted-settings
list. This extension does not bypass a restriction or add a global exemption. Installer-specific
UI must still be checked on-device. A malicious assistant authorized by the owner has substantial
power within approved targets; this is not a zero-risk claim or an upstream endorsement.

## Can an assistant use automation to give itself more access?

No. Settings, the consent app and PermissionController are rejected before alternative allowlist,
super-agent and test-session target paths (frameworks/base 0003 and 0006). The centralized Settings
list excludes them too. Editing the lists needs a signature permission that only Settings and the
consent app hold.

## What happens when access is withdrawn?

It takes effect immediately, including on live sessions:

- Turning an assistant off closes its sessions.
- Turning a target off closes every session on it and clears saved approvals for it.
- Role/permission/policy/package listeners invalidate pending work and close affected live sessions.
  Role changes also close privileged clients that retain a static permission. AppOp ignored, errored
  and reset modes close sessions (0006). Existing final authorization checks remain.
- Withdrawal invalidates outstanding consent, so reauthorization cannot revive an old pending
  request. Active closures are user/UID/target-scoped; pending invalidation is conservative across
  users. Callback latency and race behavior still require device testing.

Uninstalling an app or deleting a user removes their records.

## Does it work across users and profiles?

The owner lists are per user, and changes in one user do not close another user's sessions. The
service already checks managed-device policy, and frameworks/base 0005 rechecks it before a
session starts. The patches do not change how work profiles are handled. Neither cross-user nor
work-profile behaviour has been tested on a device.

## Can apps tell they are being automated?

Yes. The virtual touchscreen and keypad are named after the agent's package. They carry vendor
0x0000, product 0xCC03 or 0xCC01 and `BUS_VIRTUAL`, and sit on a non-default display. Any app
can read this from the input device of an event, so it can tell one assistant from another.
This is how AOSP builds it, and the patches do not change it.

**The OS takes no side.** The patches neither hide automation from apps nor give apps new ways
to refuse it. Whether an app accepts an assistant is for the app's developers and the
assistant's developers to settle. That question is outside the scope of this series.

**Precedents.**

- **GrapheneOS and app attestation.** GrapheneOS does not disguise itself as stock Android to
  pass app checks. It identifies itself honestly and asks app developers to allow it. An
  identifiable assistant is in the same position: it has to persuade apps rather than hide.
- **Accessibility services.** Apps can already list the enabled services, and since Android 14
  can mark views as hidden from services that are not accessibility tools. Android lets apps
  decide about automation, and the OS does not override them.
- **Doubao Phone Assistant.** This is from press reports, not checked against primary sources.
  In December 2025 ByteDance's assistant shipped on ZTE's Nubia M153 with OS-level input
  injection. Within days WeChat, Alipay, Taobao and banks logged users out, and WeChat control
  was withdrawn on 3 December. In June 2026 Tencent reportedly opened an agent channel to
  several phone makers on its own terms. Deep OS access did not make apps accept the assistant.
  What changed things was an agreement with the app's developer.

**Is it an open problem?** Yes, for assistants, not for the OS. Some apps will refuse automated
input, especially chat, payment and banking apps. Whether they come to accept assistants depends
on assistant developers earning that trust, through agreements, interfaces that apps provide
for the purpose, or shared standards. These patches neither help nor hinder that.

## Is the consent app already in GrapheneOS?

The source says no. At the tag, build/make includes `VirtualDeviceManager` only when
`RELEASE_PACKAGE_COMPUTER_CONTROL` is true. build/release sets that only in the `trunk_staging`
configuration, which release builds do not use.

A forum post on 1 October 2026 reports `com.android.virtualdevicemanager` appearing after
release 2026092500 ([discussion](https://discuss.grapheneos.org/d/42470)). We have not
reconciled the two. Run `pm list packages com.android.virtualdevicemanager` on an unmodified
device. If it is present, build/release 0002 can be dropped.

## Why require version 5?

Version 5 sessions must have a foreground window. Accepting version 4 would let an agent avoid
that check by asking for the older version.

## Why no master switch?

AOSP has none, and empty lists already mean the feature is off. A master switch would be one
more state to keep consistent across users.

## Why bind entries to signing certificates?

So that a different app installed under the same package name cannot inherit an earlier
approval. A key rotation that keeps the old certificate in its lineage keeps the approval.

## What will rebasing cost?

Most patches add files or hook into two call points. frameworks/base 0003 rewrites the session
creation path. It is the one most likely to conflict when AOSP changes
`ComputerControlSessionProcessor`. If AOSP adds its own owner-facing control, the owner list may
become unnecessary. Because the patches add a source rather than replace one, they can then be
dropped without migration.

## What has been tested?

| Check | Result |
|---|---|
| Twelve patches apply cleanly to pinned source | Passed; exact-prefix rerun and dirty-tree refusal also passed |
| Public extension signature and fixture Java compile against pinned public SDK | Passed (lightweight javac contract check) |
| New extension full-tree build, stubs/APK packaging and new Android tests | Not run |
| Historical pre-extension image compilation/signing | Passed for the series before the 8 November re-cut |
| Historical pre-extension Settings host tests | 11 passed, 3 skipped |
| Historical frameworks/base instrumentation tests | Compiled, not run |
| Boot identity and on-device Computer Control behavior | Still unverified |

The device checks still to run are listed in the reviewer guide, §9.

## Does this touch SELinux, verified boot, attestation or hardening?

No. The existing policy already lets `system_server` open `/dev/uinput`, where the virtual input
devices are created.

## Is an assistant or a model part of this proposal?

No. The patches name no app. Agent logic, models and per-action policy belong in the assistant.
