# FAQ for reviewers

Short answers to the questions a GrapheneOS maintainer is likely to ask. Patch details are in
the [reviewer guide](patches.md); its §8 has the source references.

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
- Its input is identifiable, as the next answers explain.

The patches do not change accessibility services.

## Can a user-installed assistant use this?

Not with these patches. `ACCESS_COMPUTER_CONTROL` is `internal|privileged` in AOSP, and the
patches keep that. Only an app built into the image and listed in a privileged-permission
allowlist can hold it. Merging the patches would therefore help only assistants that GrapheneOS,
or someone building their own image, chooses to ship.

The options, for maintainers to weigh:

1. **Keep it privileged.** This matches AOSP's trust model and adds nothing new to review. Users
   would only benefit if an assistant were shipped in the image.
2. **Let the owner grant it to an installed assistant from Settings.** The role, both switches
   and the consent dialog would still apply. This needs a further patch to how the permission is
   granted, plus a review of the service's checks, which treat an app without the granted
   permission as a test agent. The risk is an owner being talked into granting it to a malicious
   app. The mitigations are the several deliberate steps required, the session notification and
   per-target consent. That is a smaller grant than an accessibility service, which an owner can
   already give to any installed app.

This repository implements option 1. We would like the maintainers' view before writing
option 2.

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

## Can apps tell they are being automated?

Yes. The virtual touchscreen and keypad are named after the agent's package. They carry vendor
0x0000, product 0xCC03 or 0xCC01 and `BUS_VIRTUAL`, and sit on a non-default display. Any app
can read this from the input device of an event. The patches do not hide this, and they should
not: an app that wants to refuse automation can.

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
