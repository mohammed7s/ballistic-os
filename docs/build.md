# Build procedure

This is the reusable procedure. Machine addresses, build IDs, hashes and session names belong in
[dated records](log/README.md). Check [current context](CONTEXT.md) for what has been validated.

## Prerequisites

Use the upstream [GrapheneOS build guide](https://grapheneos.org/build) for the pinned release's
host packages and device support. This recipe expects Linux, an unprivileged build user, `repo`,
Git, the upstream toolchain and adequate resources (plan for at least 64 GB RAM and roughly
500 GB disk). Vendor extraction uses adevtool; `scripts/build.sh` documents its dependencies.

Read MANIFEST and [the patch index](../patches/README.md) before starting. Preserve an existing
checkout's local work; a fresh source directory is preferable for independent reproduction.

## Sync and compile — build machine

From this repository:

```bash
scripts/sync.sh /path/to/grapheneos-source
DEVICE=blazer BUILD_NUMBER=<chosen-number> scripts/build.sh /path/to/grapheneos-source
```

Replace the path and build number. `sync.sh` verifies the pinned manifest tag and applies the
series with `git am`. The application helper audits all five patched projects against
[source-pins.json](../source-pins.json), accepting only the pin or an exact patch-ID prefix.
It refuses dirty trees, foreign commits and mismatched bases before applying anything; it does
not rebase or reset local work. Preserve and resolve divergent work separately. For an already
synced pinned tree, run `python3 scripts/apply-patches.py /path/to/grapheneos-source` from this
recipe without repeating a sync. Inspect conflicts rather than skipping a failed patch.
`build.sh` generates vendor files, builds target-files and otatools, then finalizes artifacts
under the source tree's `releases/<chosen-number>/`. It refuses root execution.
`SKIP_VENDOR=1` reuses existing vendor files and `CLEAN=1` deletes build output; use only when
appropriate to that checkout. `OFFICIAL_BUILD` is deliberately unset, so Updater is omitted.

Record the recipe commit, manifest tag, applied source revisions, build number, tool versions,
actual build exit status and artifact hashes. A monitor exiting successfully is not build proof.

## Extension compile and regression targets

### Development SDK emulator

For a separate x86_64 development image, use the same pinned patched source and an output
directory outside that source tree:

```bash
BUILD_NUMBER=<chosen-number> BUILD_JOBS=18 \
  scripts/build-emulator.sh /path/to/source /path/to/separate-emulator-output
```

This selects `sdk_phone64_x86_64-cur-userdebug` and the supported local Ninja executor, then
builds `emu_img_zip` plus the public Computer Control stub. It verifies consent-app packaging
is enabled and checks the installed
wrapper/XML and image ZIP after compilation. It does not clean the Pixel output, run vendor
extraction, sign a production release, or flash a device. The output-directory lock prevents
two invocations of this script using the same output; coordinate other source-tree users before
starting. Build as the existing unprivileged source owner. This is a development target, not
a supported GrapheneOS device release. Build and runtime evidence belongs in the dated log;
the existence of this script does not establish boot or Computer Control functionality.

### Platform modules

The fifteen-patch extension has produced unsigned OS packages and passed focused host tests;
see the [image record](log/2026-11-22-unsigned-image.md) for limits and remaining validation. Before signing, build the wrapper/stubs, PermissionController, Settings,
VirtualDeviceManager, ordinary fixture APKs and instrumentation packages using the exact commands
in [assistant integration](assistant-integration.md#fixtures-and-build-host-commands). Run the
[focused host and device matrix](regression-tests.md). Do not install the fixtures into the product
or treat instrumentation-package compilation as execution. Record actual output paths and hashes.

## Sign — separate signing machine

See [keys.md](keys.md) first. Configure the actual build-host SSH destination and command:

```bash
BOX=<build-user@host> BOX_SSH='ssh -p <port> -i <ssh-key>' BOX_SRC=<source-path> BUILD_NUMBER=<chosen-number> scripts/sign.sh fetch
# Once per device/key identity, only when creating a new store:
DEVICE=blazer scripts/sign.sh keygen
DEVICE=blazer BUILD_NUMBER=<chosen-number> scripts/sign.sh release
```

These are templates, not commands with working placeholder values. `fetch` copies tools and
unsigned artifacts. `keygen` refuses an existing key store. `release` asks for the passphrase,
signs the factory image and full OTA, verifies the factory signature and prints the expected
boot key hash. Keep signed target-files for future delta work. The cloud test exception in the
log is historical; it does not change production key custody.

## Install and validate

Follow [flashing.md](flashing.md), then [regression-tests.md](regression-tests.md). Verify the
installed build and key independently. A successful image build does not establish runtime
access, safe authorization, working app integration or OTA publication.
