# Patch series re-cut: eleven patches to eight (8 November 2026)

## Why

The eleven-patch series recorded its own review history. Patch 9 existed only to remove a
lock-order cycle with WindowManager that patch 7 introduced, so stopping after patch 7 gave a
deadlock-prone tree. Patch 6 (version 5 flag) and patch 8 (protected targets) completed earlier
patches. Reviewers need the final design, with no intermediate state worse than the one before.
Three new files also carried a "The Ballistic Authors" copyright header; GrapheneOS's own new
files carry no header, so the headers were removed.

## Mapping

| New | Contents | Old patches |
|---|---|---|
| build_release 0001 | access, per-app consent and version 5 flags | 1 + 6 |
| build_release 0002 | consent app | 2 |
| frameworks_base 0001 | user allowlist | 3 |
| frameworks_base 0002 | allowlist API | 4 |
| frameworks_base 0003 | revocation, user lifecycle, creation reservation | 7 + 9 |
| frameworks_base 0004 | parameter validation | 10 |
| frameworks_base 0005 | recheck before publication | 11 |
| packages_apps_Settings 0001 | Settings pages, including protected targets | 5 + 8 |

Each new frameworks_base and Settings commit is a snapshot of the old series at the end of the
corresponding old patch, so every intermediate state except the removed post-patch-7 state
already existed in the old series. The build_release 0001 state, three flags without the consent
app, is new.

## Verification performed

- The touched files were fetched from GrapheneOS's repositories at tag `2026110200`. All eleven
  old patches applied with `git am`. The eight new patches were generated from those trees.
- Old and new final trees differ only by the removed licence comment blocks: 16 lines in
  `ComputerControlUserAllowlist.java`, 16 in `ComputerControlUserAllowlistTest.java` and 15 in
  `strings_computer_control_ext.xml`. No code, string or test changed.
- The new patches applied with `git am` to fresh copies of those files and produced identical
  trees. `git diff --check` was clean.

Not performed: compiling the new series, or compiling each intermediate commit. The compiled,
signed and flashed build `2026110700` used the old eleven-patch snapshot, which is still in git
history before this change. Its final source differs from the new series only by the comment
blocks above.

## Consent app finding

At the tag, build/make adds `VirtualDeviceManager` only when `RELEASE_PACKAGE_COMPUTER_CONTROL`
is true (`target/product/media_system.mk:48-49`). build/release sets it only in
`flag_values/trunk_staging/`, and release `cur` inherits `cp2a` without it. A forum post on
1 October 2026 (discuss.grapheneos.org/d/42470) reports `com.android.virtualdevicemanager`
appearing after GrapheneOS release 2026092500. The two have not been reconciled. Check
`pm list packages com.android.virtualdevicemanager` on an unmodified GrapheneOS device of the
same release before deciding whether build_release 0002 is needed.
