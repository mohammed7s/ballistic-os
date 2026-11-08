# ballistic-os

**Patches for GrapheneOS that let the device owner choose which assistant may use Android 17's
Computer Control, and on which apps.**

Android 17 includes Computer Control: an assistant app operates other apps on a hidden virtual
display, with the user's consent for each app. On GrapheneOS it is compiled off. The apps
allowed to use it also come from Google's remote configuration (DeviceConfig), which GrapheneOS
never receives. These patches switch the feature on and give that decision to the owner, in
Settings.

This repository holds a pinned GrapheneOS tag, the patches as `git format-patch` files and the
build scripts. It contains no Android source and no assistant.

## If you never open the setting, nothing changes

Both new lists start empty. No app can open a session until the owner allows an assistant and
at least one target app. Today only a preinstalled app can hold the permission, so on a stock
image there may be no app to allow at all.

## The patches

Eight patches in three repositories, against GrapheneOS tag `2026110200`.

| Group | Repository | Patch | What it does |
|---|---|---|---|
| Turn it on | build/release | 0001 | Enable Computer Control, per-app consent and version 5 |
| | build/release | 0002 | Build the AOSP consent dialog app |
| Owner control | frameworks/base | 0001 | Check an owner-edited list next to the DeviceConfig list |
| | frameworks/base | 0002 | System API so Settings can edit that list |
| | packages/apps/Settings | 0001 | Switches to allow an assistant and to allow each target app |
| Hardening | frameworks/base | 0003 | Settings can never be automated; withdrawal wins over a session being created |
| | frameworks/base | 0004 | Validate session parameters inside the service |
| | frameworks/base | 0005 | Recheck permissions and policy before a session starts |

Each patch is explained in the [reviewer guide](docs/patches.md). Apply order and commands are
in the [patch index](patches/README.md).

## What stays the same

- The permission stays privileged, so only preinstalled, allowlisted apps can request it.
- The assistant must hold the assistant role, which the user chooses.
- The AOSP consent dialog still asks per target app.
- The DeviceConfig path is kept and still works where it exists.
- No change to SELinux policy, verified boot, keystore, attestation or GrapheneOS hardening.

## Open problem: assistants the user installs

Because the permission stays privileged, only an assistant built into the image can use it.
Merging these patches alone would not let a user install an assistant of their choice and allow
it.

The aim is for the owner to be able to choose any assistant, including one they install
themselves, without making the device less secure. Android already has a precedent: USB
debugging. It grants powers as broad as this one, including input into any app, screen capture
and permission grants, behind deliberate steps that only the owner can take. Computer Control
could follow the same principle: powerful, off by default, and fully in the owner's hands.

We have not solved this, and these patches do not attempt it. The requirements and one candidate
approach are in the [FAQ](docs/faq.md#can-a-user-installed-assistant-use-this). We would like
the maintainers' view before writing a patch.

## Status

8 November 2026. An image with this change set compiled, was signed with disposable test keys,
and was flashed and relocked on a test Pixel 10 Pro. That build used the series before it was
re-cut into eight patches; the source differs only by removed licence comments. Focused Settings
host tests passed 11 cases with 3 skipped. Boot identity and on-device Computer Control behaviour are not yet verified.
This is not a release. Evidence is in the [validation record](docs/regression-tests.md).

## Build

Read the [build procedure](docs/build.md) first. Signing happens on a separate machine, as
described in [keys](docs/keys.md).

```bash
scripts/sync.sh     # GrapheneOS at the tag in MANIFEST, with patches/ applied
scripts/build.sh
```

Then follow the [installation procedure](docs/flashing.md).

## More

[Reviewer guide](docs/patches.md) · [FAQ](docs/faq.md) · [Roadmap](docs/PLAN.md) ·
[Current context](docs/CONTEXT.md) · [Source research](docs/FACTS.md) ·
[Dated records](docs/log/README.md)

This work started alongside [Ballistic](https://github.com/mohammed7s/ballistic), an assistant
app. The patches name no app and work with any assistant that passes the checks above.

Apache-2.0. Maintainer: [@mohammed7s](https://github.com/mohammed7s).
Not affiliated with or endorsed by GrapheneOS.
