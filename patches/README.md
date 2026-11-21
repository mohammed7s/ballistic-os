# Patch index

Fifteen `git format-patch` files against GrapheneOS **`2026110200`**. The original eight patches
are preserved; four additions implement the installed-assistant extension by default, followed
by two packaging corrections and a Kotlin callback type correction found during the cloud build. The original twelve patches
remain unchanged.
Exact upstream commits are recorded in [source-pins.json](../source-pins.json).
Design: [reviewer guide](../docs/patches.md). Validation: [21 November evidence](../docs/log/2026-11-21-installed-assistants.md).

| Directory | Source path | Patches |
|---|---|---|
| `build_release/` | `build/release` | 0001 feature/version/consent flags; 0002 consent-app product flag |
| `frameworks_base/` | `frameworks/base` | 0001 owner lists; 0002 management API; 0003 revocation/construction; 0004 parcel validation; 0005 final authorization |
| `frameworks_base/` | `frameworks/base` | **0006** installed-assistant role permission, mandatory ordinary owner gates, live revocation, pending-consent invalidation, protected PermissionController, candidate API and upgrade reconciliation |
| `frameworks_base/` | `frameworks/base` | **0007** shared wrapper installation and compile-only public stubs; **0008** moves installation out of the consent app dependency |
| `build_make/` | `build/make` | **0001** installs the wrapper from the system_ext product under the consent-app release flag |
| `packages_apps_Settings/` | `packages/apps/Settings` | 0001 original owner UI; **0002** one centralized page with selected assistant and searchable inline target switches; **0003** explicit switch callback return types |
| `packages_modules_Permission/` | `packages/modules/Permission` | **0001** optional assistant role grant and configuration regression |

Apply numbered order within each repository. All five repositories are required for the advertised
flow. Settings 0002 uses frameworks/base 0006's signature-protected eligibility query. The role
permission and PermissionController grant must ship together. The system_ext product configuration installs
the wrapper when the consent-app release flag is enabled; the wrapper requires its existing
registration XML. There is no AppFunctions or sepolicy patch.

## Apply and verify

After syncing the pinned manifest on a build host:

```bash
python3 /path/to/ballistic-os/scripts/apply-patches.py /path/to/source
```

This checks all project bases and worktrees before mutation. It accepts pristine pinned projects
or an exact patch-ID prefix of the recipe, skips that prefix, and uses `git am` without three-way
fallback. A dirty tree, different base, old eleven-commit layout or unrelated commit stops it;
preserve that work and prepare a separate pinned checkout. Do not reset it or silently rebase.
`scripts/sync.sh` invokes this same application step, including the Permission module.

For lightweight verification with the five existing `platform_*` research clones:

```bash
python3 scripts/verify-patches.py /path/to/research-clones
```

It makes disposable shared sparse clones, applies all patches with `git am` to the pinned commits,
checks rerun idempotence and dirty-tree refusal, and prints final tree identities. It does not sync
Android, compile an image, or alter the research worktrees.

## Regenerate

Commit each focused source change above the pinned baseline plus existing patches, then export
it with `git format-patch -1 --stdout`. Keep the first eight unchanged when extending the series.
Clean-application checks are required after regeneration. Updating the source release is a separate
reviewed operation: update MANIFEST and source pins together and record the rebase explicitly.
