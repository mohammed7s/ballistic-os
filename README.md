# ballistic-os

**Patches for GrapheneOS that let the device owner choose an installed assistant for Android 17
Computer Control, and the apps it may operate.**

Computer Control runs target apps on a separate virtual display, with per-target system consent.
At the pinned GrapheneOS release it is compiled off and its vendor allowlists are unavailable.
This experimental recipe enables it and adds deliberate owner controls in Android Settings.
It contains a pinned source recipe, format-patches, build scripts and small integration fixtures;
no production assistant, model or app policy engine.

## Owner experience

Install an eligible assistant normally and choose it as the default digital assistant in Settings.
Open **Apps > Special app access > Screen automation**: one centralized page shows the chosen
assistant's automation switch and a **searchable installed-app list with individual inline target
switches**. Fresh grants all start off. No assistant is branded or preselected by these patches.
After enabling both switches, separately approve the system's per-target consent request.

The assistant is an independently signed `/data/app` APK. It needs no preinstallation, platform
signature, root or ADB permission grant. Choosing its role grants the requested Computer Control
permission; that alone does not authorize a session. The [integration contract](docs/assistant-integration.md)
explains eligibility, notifications, library loading, version 5, revocation and the test fixtures.

## Security boundaries

- Ordinary assistants require both owner switches, even when vendor allowlists contain matches.
- Assistant role, permission, AppOp, signer/user binding, foreground visibility, notification,
  device policy and per-target consent checks remain enforced.
- Withdrawal invalidates pending requests and closes affected active sessions. Settings, the
  consent app and PermissionController cannot be automation targets, including special paths.
- Preinstalled privileged clients retain their existing vendor path, with role and other checks.
- No SELinux, verified-boot, keystore, attestation or global hidden-API exemption is added.

An authorized assistant has substantial power inside approved apps. These OS gates do not decide
whether an individual action, such as sending or paying, is appropriate. That belongs to the
assistant's policy; apps remain free to recognize or reject automation.

## Patches and status

**21 November 2026:** fourteen patches in five repositories, against GrapheneOS tag `2026110200`.
The original eight remain intact. The extension adds a role permission grant, lifecycle handling,
shared-library packaging/public compile stubs and the centralized Settings page. It applies by
default through `scripts/sync.sh`; there is no silently selected optional variant or newer base.

Clean patch application and a lightweight javac check of the pinned public extension signature
and fixture Java are recorded in the [new evidence](docs/log/2026-11-21-installed-assistants.md).
The extension's full OS/Soong build, Settings and instrumentation tests, APK packaging and device
flow are **not run**. Earlier compilation/signing/flashing and 11 Settings host passes with 3 skips
belong to the pre-extension series; they do not validate this change. This is not a release or a
claim of GrapheneOS endorsement. See [validation](docs/regression-tests.md).

## Build

Read the [build procedure](docs/build.md) and [patch index](patches/README.md) first. Use an adequately
provisioned build host; signing remains on a separate machine under the [key procedure](docs/keys.md).

```bash
scripts/sync.sh /path/to/grapheneos-source
scripts/build.sh /path/to/grapheneos-source
```

The application step verifies [pinned project revisions](source-pins.json), preserves unrelated
work, and accepts only an exact prefix of this recipe. It does not silently rebase. Installation
requires the separate [device procedure](docs/flashing.md) and current authorization.

[Reviewer guide](docs/patches.md) · [FAQ](docs/faq.md) · [Roadmap](docs/PLAN.md) ·
[Current context](docs/CONTEXT.md) · [Source research](docs/FACTS.md) · [Dated records](docs/log/README.md)

This work started alongside [Ballistic](https://github.com/mohammed7s/ballistic). Its real app
adapters, models and policy remain separate. AppFunctions access is not enabled by this recipe.

Apache-2.0. Maintainer: [@mohammed7s](https://github.com/mohammed7s).
Not affiliated with or endorsed by GrapheneOS.
