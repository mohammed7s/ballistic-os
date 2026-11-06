# Patches

The Computer Control gate for Ballistic for GrapheneOS: eleven patches, one commit each, made with
`git format-patch` against GrapheneOS tag **`2026110200`**. Design, privacy argument, verified
facts and the first-build checklist: [`../docs/patches.md`](../docs/patches.md).

Status: applied cleanly with `git am` to fresh clones of the tag; not yet compiled or run.

## Apply order

| # | Directory here | GrapheneOS repo | Path in the tree | Patch | Lines | Change |
|---|---|---|---|---|---|---|
| 1 | `build_release/` | `platform_build_release` | `build/release` | `0001-computer-control-flags.patch` | 55 | 2 files, +12 |
| 2 | `build_release/` | `platform_build_release` | `build/release` | `0002-computer-control-consent-app.patch` | 34 | 1 file, +4 |
| 3 | `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` | `0001-computer-control-user-allowlist.patch` | 781 | 4 files, +616 −5 |
| 4 | `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` | `0002-computer-control-user-allowlist-api.patch` | 309 | 5 files, +225 |
| 5 | `packages_apps_Settings/` | `platform_packages_apps_Settings` | `packages/apps/Settings` | `0001-computer-control-user-allowlist-ui.patch` | 444 | 6 files, +197 −16 |
| 6 | `build_release/` | `platform_build_release` | `build/release` | `0003-computer-control-version-five.patch` | 26 | 1 file, +6 |
| 7 | `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` | `0003-computer-control-revocation-hardening.patch` | 742 | 7 files, +296 −53 |
| 8 | `packages_apps_Settings/` | `platform_packages_apps_Settings` | `packages/apps/Settings` | `0002-computer-control-protected-targets.patch` | 53 | 2 files, +6 −1 |
| 9 | `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` | `0004-computer-control-creation-reservation.patch` | 510 | 2 files, +210 −121 |
| 10 | `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` | `0005-computer-control-server-parameter-validation.patch` | 237 | 2 files, +134 −4 |
| 11 | `frameworks_base/` | `platform_frameworks_base` | `frameworks/base` | `0006-computer-control-final-authorization.patch` | 374 | 4 files, +162 −27 |

Within a repository the numbered order matters (4 depends on 3). Across repositories the order
does not matter for applying, but all eleven are needed for a working build: 5 calls the API from 4,
and 3–5 do nothing without the flags from 1. Patch 7 requires version 5, enabled by 6.
The follow-up preserves one-time consent, rechecks grants before creation, removes deleted-user
records, and prevents automation of the permission editors. Patches 9–11 correct the creation
locking from 7, validate untrusted Parcel parameters at the server boundary, and recheck mutable
permissions and policy before publishing a session. Do not stop at patch 7: its construction lock
introduces a WindowManager lock-order cycle, resolved by 9.

No `system/sepolicy` patch: the existing policy already lets system_server use `/dev/uinput`
(`docs/patches.md` §3.3).

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
