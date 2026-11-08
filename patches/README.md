# Patches

Owner-controlled Computer Control for GrapheneOS: eight patches, one commit each, made with
`git format-patch` against GrapheneOS tag **`2026110200`**. What each patch does and why:
[reviewer guide](../docs/patches.md). Common questions: [FAQ](../docs/faq.md).

Status: all eight apply with `git am` to the tag. An image built from the earlier eleven-patch
form of this series compiled, was signed, flashed and relocked; its source differs only by
removed licence comments. On-device behaviour is not yet verified; see
[validation](../docs/regression-tests.md). The re-cut is recorded in
[the log](../docs/log/2026-11-08-patch-series-recut.md).

## Apply order

| Directory here | GrapheneOS repository | Path in the tree |
|---|---|---|
| `build_release/` | `platform_build_release` | `build/release` |
| `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` |
| `packages_apps_Settings/` | `platform_packages_apps_Settings` | `packages/apps/Settings` |

Within a repository, apply in numbered order. Across repositories the order does not matter for
applying, but a working build needs all eight: Settings 0001 calls the API from
frameworks/base 0002, and nothing works without the flags from build/release 0001. Unlike the
earlier eleven-patch form, no intermediate frameworks/base state contains the lock-order cycle
that a later patch had to remove. Intermediate commits have not been compiled one by one.

| Patch | File | Lines | Change |
|---|---|---|---|
| build/release 0001 | `0001-computer-control-flags.patch` | 72 | 3 files, +18 |
| build/release 0002 | `0002-computer-control-consent-app.patch` | 34 | 1 file, +4 |
| frameworks/base 0001 | `0001-computer-control-user-allowlist.patch` | 749 | 4 files, +584 −5 |
| frameworks/base 0002 | `0002-computer-control-user-allowlist-api.patch` | 309 | 5 files, +225 |
| frameworks/base 0003 | `0003-computer-control-revocation-and-creation.patch` | 1105 | 7 files, +465 −133 |
| frameworks/base 0004 | `0004-computer-control-parameter-validation.patch` | 245 | 2 files, +134 −4 |
| frameworks/base 0005 | `0005-computer-control-final-authorization.patch` | 385 | 4 files, +162 −27 |
| Settings 0001 | `0001-computer-control-user-allowlist-ui.patch` | 461 | 6 files, +187 −16 |

No `system/sepolicy` patch is needed (reviewer guide §8.4).

## Apply

In a GrapheneOS checkout at tag `2026110200` (`P` is this directory):

```bash
P=/path/to/ballistic-os/patches
git -C build/release          am "$P"/build_release/*.patch
git -C frameworks/base        am "$P"/frameworks_base/*.patch
git -C packages/apps/Settings am "$P"/packages_apps_Settings/*.patch
```

To check a patch without applying it: `git -C <path> apply --check <patch>`. If `git am` stops on
a conflict after a GrapheneOS rebase, `git am --abort` and regenerate the patch from a work branch
rebased onto the new tag.

## Regenerate

From a work clone with the patches committed on top of the tag:

```bash
git format-patch 2026110200..HEAD -o <dir>
```
