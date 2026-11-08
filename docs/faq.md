# FAQ for reviewers

Short answers to the questions a GrapheneOS maintainer is likely to ask. Patch details are in
the [reviewer guide](patches.md); its §8 has the source references.

This repository covers OS-level permissions only: which assistant may use Computer Control, on
which apps, under the owner's control. How an assistant behaves inside apps, and how apps treat
it, is outside its scope.

## Why not just enable the flags and use the existing allowlist?

The existing allowlist comes from DeviceConfig, Google's remote configuration, which GrapheneOS
does not receive. Its fallback files under `/data/system/computercontrol/` can only be written
with a computer connection or root. Enabling the flags alone would leave the feature unusable,
or usable only through a developer workflow. The patches add an owner list beside it, edited in
Settings.

## What does this add for someone who never turns it on?

- The Computer Control permissions become defined, and the consent dialog app is installed.
- Settings shows Screen automation pages, with every entry "Not allowed".
- `system_server` reads one small, empty owner-list file at boot.
- Four new hidden binder methods exist, callable only with a signature permission.

No app can open a session. A session also needs an app that holds the privileged permission. A
GitHub code search of the GrapheneOS organisation found no app manifest or privileged-permission
allowlist requesting it. Search coverage of large repositories is incomplete, so confirm on a
device with `dumpsys package | grep ACCESS_COMPUTER_CONTROL`.

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

The patches do not change accessibility services.

## Can a user-installed assistant use this?

Not yet. This is an open problem, and these patches do not attempt to solve it.

**Where things stand.** `ACCESS_COMPUTER_CONTROL` is `internal|privileged` in AOSP, and the
patches keep that. Only an app built into the image and listed in a privileged-permission
allowlist can hold it. Merging the patches would therefore help only assistants that GrapheneOS,
or someone building their own image, chooses to ship.

**The aim.** The owner should be able to choose any assistant, including one they installed
themselves, without the device becoming less secure than it is today.

**The precedent.** USB debugging already gives the owner powers at least this broad. Through
it, a connected computer can inject input into any app, capture the screen and grant
permissions. Android ships that safely by putting it behind steps only the owner can take:
unhide developer options, turn on USB debugging, then approve the computer's key on the phone.
It is off by default and the owner can revoke it at any time. AOSP's own Computer Control check
also already accepts a test-only agent that holds the permission through the debugging shell.
The code therefore already allows a non-privileged agent, as long as the owner set it up.

**What a solution must keep.**

- Only the owner can grant access, through deliberate steps in Settings. No app can grant it to
  itself, and automation cannot reach those steps.
- Off by default and revocable at any time. Revoking closes running sessions.
- Visible while in use.
- The owner switches and the per-target consent dialog still apply.
- Nothing changes for owners who never use it.
- An owner talked into it by a malicious app is at least as well protected as with an
  accessibility service today.

**One candidate approach.** Android can grant a permission to whichever app holds a role. At
the tag, the assistant role already grants four permissions declared `internal|role`,
`signature|role` or `signature|module|role`, and the role is not limited to system apps. Adding
`role` to the protection level of `ACCESS_COMPUTER_CONTROL`, and listing it under the assistant
role in PermissionController, would give the access to whichever app the owner makes the default
digital assistant. Choosing another assistant would remove it. The service reads the grant
through a normal permission check, so its other checks would not need to change.

Open questions about that approach:

- Is choosing a default assistant a deliberate enough step for this power? It may need an extra
  confirmation, in the way developer options must be unlocked before USB debugging appears.
- Should Android's restricted-settings protection, which already makes sideloaded apps wait for
  extra owner approval before they can become accessibility services, apply here too?
- Does PermissionController, a separately updated module, need the same change in every build?

Nothing here is written or tested. We would like the maintainers' view first.

## Can an assistant use automation to give itself more access?

No. Settings and the consent dialog app are rejected as targets before every other check, even
if DeviceConfig lists them (frameworks/base 0003). Settings also hides their target pages
(Settings 0001). Editing the lists needs a signature permission that only Settings and the
consent app hold.

## What happens when access is withdrawn?

It takes effect immediately, including on live sessions:

- Turning an assistant off closes its sessions.
- Turning a target off closes every session on it and clears saved approvals for it.
- Revoking the role, a permission or the AppOp, or changing device policy, stops a pending
  request from becoming a session (frameworks/base 0003 and 0005).

Uninstalling an app or deleting a user removes their records.

## Does it work across users and profiles?

The owner lists are per user, and changes in one user do not close another user's sessions. The
service already checks managed-device policy, and frameworks/base 0005 rechecks it before a
session starts. The patches do not change how work profiles are handled. Neither cross-user nor
work-profile behaviour has been tested on a device.

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
| Patches apply to the tag | Passed |
| Image compiles and signs | Passed, for the series before its 8 November re-cut, which differs only in comment headers |
| Settings host tests | 11 passed, 3 skipped |
| frameworks/base instrumentation tests | Compiled, not run |
| Boot identity on the test phone | Not yet verified |
| Any on-device Computer Control behaviour | Not yet tested |

The device checks still to run are listed in the reviewer guide, §9.

## Does this touch SELinux, verified boot, attestation or hardening?

No. The existing policy already lets `system_server` open `/dev/uinput`, where the virtual input
devices are created.

## Is an assistant or a model part of this proposal?

No. The patches name no app. Agent logic, models and per-action policy belong in the assistant.
