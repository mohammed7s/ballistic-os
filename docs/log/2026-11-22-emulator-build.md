# Computer Control SDK-emulator build — 22 November 2026

The owner authorized the app session to use the existing Contabo host for a separate emulator
build. This supersedes the earlier reservation of build-server work to the OS session for this
specific task. Pixel build outputs, signing identities and device data are retained.

## Verified preparation

The clean rebuilt host at `5.253.233.224` was reached using the pinned SSH host key. It had
267 GiB available on the 581 GiB filesystem and 94 GiB RAM, with no active compiler/build job.
Existing source: `/srv/ballistic/gos`; source owner: `ballistic-build`. The source remains pinned
to GrapheneOS `2026110200` with the installed-assistant patch recipe. No resync, clean, signing
or phone operation was performed.

The pinned Goldfish product declares `sdk_phone64_x86_64`, device `emu64x`. A separate output
directory `/srv/ballistic/out-emulator-20261122` was created for the unprivileged build user.
The initial configuration attempt stopped because that user could not create a sibling directory
under `/srv/ballistic`; creating just the new output directory resolved this permission issue.
`lunch sdk_phone64_x86_64-cur-userdebug` then passed, reporting Android 17, x86_64 and security
patch `2026-11-01`. `get_build_var RELEASE_PACKAGE_COMPUTER_CONTROL` returned `true`.
`PRODUCT_OUT` resolves to `/srv/ballistic/out-emulator-20261122/target/product/emu64x`.

The source's `device/generic/goldfish/build/tasks.workaround/emu_img_zip.mk` defines the
`emu_img_zip` goal and `sdk-repo-linux-system-images.zip` artifact. This packages the QEMU system,
vendor and ramdisk images with the emulator kernel and configuration. Compilation and boot
are still separate checks.

## Initial attempt and resumed build

The reusable recipe is [build-emulator.sh](../../scripts/build-emulator.sh). Shell syntax and
diff checks passed locally. The build runner invokes it with `BUILD_NUMBER=2026112200` and
`BUILD_JOBS=18`, auditing the existing patch series before compilation. It does not install the
ordinary test fixtures into the product or add a permission bypass.

- Unit: `ballistic-emulator-2026112200.service`
- Invocation: `e86a72a2dd4b4a809ec60e2b4fd92541`
- Runner: `/srv/ballistic/build-emulator-20261122.sh`
- Recipe script: `/srv/ballistic/recipe/scripts/build-emulator.sh`
- Log: `/srv/ballistic/logs/emulator-2026112200.log`
- Completion status: `/srv/ballistic/logs/emulator-2026112200.exit` (written only on runner exit)
- Output: `/srv/ballistic/out-emulator-20261122`

The initial job exited 1 at `2026-11-22T10:22:49Z`, during Soong bootstrap, before OS compilation.
The default Siso executor reported `failed to load @config//main.star: open main.star: no such
file or directory`. The generated file exists in the separate absolute output directory; its
resolution by the executor failed. The source's `build/soong/ui/build/config.go` supports
`SOONG_NINJA=ninja`, so the recipe now explicitly selects that local executor. No platform source,
feature flag, sandbox or authorization check was changed to address this build-tool failure.

The resume uses the same output directory and preserves the original failure evidence:

- Unit: `ballistic-emulator-2026112200-resume1.service`
- Invocation: `715577c84e2042948865340dfaf12cf0`
- Runner: `/srv/ballistic/build-emulator-20261122-resume1.sh`
- Log: `/srv/ballistic/logs/emulator-2026112200-resume1.log`
- Completion status: `/srv/ballistic/logs/emulator-2026112200-resume1.exit`

The resumed job passed the original failure and compiled the bootstrap build tools. It then
failed at `2026-11-22T10:43:20Z` after an 18-minute build invocation. Soong's analysis rejected
`continuous_native_tests` at `platform_testing/Android.bp:255`: `Path is outside directory` for
the generated `net-tests-utils-host-common.jar` under the absolute external output directory.
This was discovered on the owner's next status request at approximately 17:15 UTC; the build
was not running during the intervening hours. No OS image was produced.

## Resume 2: source-relative dedicated output

The recipe now requires a direct `SOURCE_DIR/out-emulator-*` directory and exports its basename
as relative `OUT_DIR`. The Pixel's `out/` and the failed external output are retained. This
addresses the reported path-validation failure without changing platform code or disabling
validation. Shell syntax and diff checks pass; full build validation remains pending.

- Unit: `ballistic-emulator-2026112200-resume2.service`
- Runner: `/srv/ballistic/build-emulator-20261122-resume2.sh`
- Log: `/srv/ballistic/logs/emulator-2026112200-resume2.log`
- Completion status: `/srv/ballistic/logs/emulator-2026112200-resume2.exit`
- Output: `/srv/ballistic/gos/out-emulator-20261122`

At `2026-11-22T18:39:01Z`, resume 2 was active and had passed bootstrap and Soong analysis.
Ninja was compiling the full image graph: 5,055 of 162,044 actions (3% by action count), with
active clang processes and 251 GiB free. This establishes progress past both earlier failures;
action percentage is not elapsed-time percentage, and image completion/boot remain pending.

The ThinkPad was reachable again at 17:15 UTC. Its separate stock API-37 SDK download process
survived the SSH disconnect but still reported 22% and had no installed package metadata. This
download is not the patched image and does not establish Computer Control availability.

The systemd job survives an SSH disconnect. Inspect its actual log and exit status before
reporting completion. It builds the emulator ZIP and public Computer Control compile stub, then
checks wrapper/XML installation and records the image SHA-256. A started unit is not an image
build result. No compatible image has booted and no Computer Control session has run yet.

## Delivery and runtime work remaining

After successful compilation, transfer and hash-check the image on the ThinkPad. Use a new,
visible SDK emulator, retaining `AndroidWorldAvd` and running only one virtual device at a time.
Verify the actual runtime flags, shared library, owner Settings flow, assistant role, target
consent, UI tree, input, Stop and revocation. Install the APK and its separately built emulator
test driver with the same signer. AndroidWorld API-37 setup/checker compatibility and protected
task classification remain app-harness work; an image build alone does not establish suite readiness.
