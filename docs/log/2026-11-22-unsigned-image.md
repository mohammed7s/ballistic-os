# Installed-assistant unsigned image — 22 November 2026

The fifteen-patch code from recipe `47c4d95` completed the full `blazer-cur-user`
`target-files-package otatools-package` build as `2026112100` on Contabo, using pinned
GrapheneOS `2026110200`. Recipe `ec01680` corrected only test instructions. The source and build
fixes are recorded in [the previous log](2026-11-21-cloud-build-fixes.md).

## Executed validation

The three focused Settings Robolectric classes completed with **14 passed, 0 failed and 3
assumption skips**. Agent-page summaries: 4 passed, 3 skips for disabled per-app-consent flag
configurations; consent-controller calls: 7 passed; central-page search/candidate filtering:
3 passed. Logs: `/tmp/atest_result_ballistic-build/20261121_170343___1o077b/`.
These are host tests. TradeFed's generic "1 device" summary does not represent testing the Pixel.
Service/PermissionController instrumentation modules compiled but their device tests have not run.

The image build reported `8h33m33.96s Build Succeeded: 143484 steps`, with total invocation
08:34:01. `script/finalize.sh` completed. The target-files ZIP contains no
`OrdinaryComputerControl` fixture entries. Unsigned artifacts on Contabo:

| Path under `/srv/ballistic/gos/releases/2026112100/` | Bytes |
|---|---:|
| `blazer-target_files.zip` | 4,581,620,889 |
| `blazer-otatools.zip` | 536,798,522 |

These are inputs to release signing, not a verified signed installation ZIP.

## Separate fixture correction and resume 5

After image packaging, the runner copied the ordinary fixtures into the source and attempted to
build them. Soong rejected `android_app_defaults`, which is not registered at this pin. The
pipeline therefore exited 1 at `2026-11-22T00:47:14Z` despite successful preceding OS packaging.

Fixture commit `7a791cb` replaces that module type with `java_defaults`. Pinned
`build/soong/java/java.go:51` registers it and `DefaultsFactory` at line 3855 includes app,
SDK, signing, optimization and uses-library properties. This changes only the separate fixture
recipe; no OS patch or packaged image changes. The remote fixture file matched its prior recipe
before replacement.

Resume 5 skips the completed image/test stages, checks library/XML presence and fixture absence
in the target-files archive, records unsigned hashes and builds only the three ordinary fixture
APKs. Runner: `/srv/ballistic/build-resume5-20261122.sh`; unit
`ballistic-build-2026112100-resume5.service`, invocation `9fa2cdfd060f4bea971220406efe4618`.
Log and exit files: `/srv/ballistic/logs/build-2026112100-resume5.{log,exit}`.
Recipe archive `7a791cb` SHA-256 matched locally and remotely:
`4d3d9a2bacc4139248918151e26dad8549cf85e8e382077b175904830b3d7484`.
Resume 5 completed at `2026-11-22T01:25:51Z` with exit 0. The three fixture APKs
compiled successfully (62 incremental build steps; 35m44s including Soong analysis).

## Signing and delivery

The ThinkPad's SSH endpoint `ubuntu@100.114.231.86` timed out on 22 November; current storage
could not be verified. Wakeel has only 25 GiB free, so no large signing workspace was started
there. The owner was asked to bring the ThinkPad online for a storage/readiness check. Signing,
transfer, device execution and flashing have not occurred for this build. The VPS and its
storage are retained as instructed; OS signing keys have not been uploaded to it.

## Completed artifact checks

The target-files archive contains both
`SYSTEM_EXT/framework/com.android.extensions.computercontrol.jar` and
`SYSTEM_EXT/etc/permissions/computercontrol.extension.xml`, and no ordinary fixture APK.
Host-generated SHA-256 records were copied to Wakeel under
`~/.cache/ballistic-contabo/artifacts/2026112100/`.

| Artifact | SHA-256 |
|---|---|
| `blazer-target_files.zip` | `499ce75f200afd4c912a1e0f60711402c0fa526296c2c9d340c8c8b7d9da60f2` |
| `blazer-otatools.zip` | `03017e7e8eda4b4ebd8d829c0cebc1100c35cf477c7823fe90d7803b2344d36c` |
| `OrdinaryComputerControlAssistant.apk` | `a1dfda0dc6caac316ff2fcd83dd379f88014ff230a6f766cc0b9db364964b31a` |
| `OrdinaryComputerControlAssistantNoPermission.apk` | `ee98d18d2c7c34f784ac4086bde727ac8c04b632acf8be7ac0d994c9384c9bca` |
| `OrdinaryComputerControlTarget.apk` | `da7bb9fbdc1dc95b2da19d98cd4250fd600bd640bf7dc923afdebcd30a93718d` |

Fixture APKs are in `out/target/product/blazer/system/app/<module>/<module>.apk` on the build
host, produced after image packaging. `apksigner verify --print-certs` passed for all three.
Their certificate SHA-256 is
`a40da80a59d170caa950cf15c18c454d47a39b26989d8b640ecd745ba71bf5dc`, distinct from the source-tree
platform certificate `c8a2e9bccf597c2fb6dc66bee293fc13f2fc47ec77bc6b2b0d52c11f51192ab8`.
These are public source-tree test certificates, not a private ordinary-app release identity.
Use an independent disposable app signer for the planned installation-provenance test.

`aapt2 dump badging` confirmed min/target SDK 37, the distinct fixture package names and required
wrapper library for both assistants. Only the positive assistant declares
`ACCESS_COMPUTER_CONTROL`; the negative fixture declares notifications only. These static APK
checks do not prove runtime loading, role grants, consent, input or revocation.

The ThinkPad was checked again after fixture completion and SSH still timed out. No signing,
large artifact transfer or phone operation was started. The cloud instance and source/output
storage remain retained as requested.
