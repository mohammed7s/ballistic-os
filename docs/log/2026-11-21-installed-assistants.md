# Installed-assistant extension — 21 November 2026

## Scope and provenance

Implemented on Wakeel in `/home/wakeel/Desktop/ballistic-os`, starting at recipe
`69b9d414c2ff4f3b599459e2be58abc55fc24220`, MANIFEST `2026110200` and the existing eight patches.
The user-provided untracked handover was preserved, updated with the corrected centralized Settings
experience and added to the documentation. No new GrapheneOS release, AppFunctions capability,
Ballistic app adapter, production key, device operation or cloud operation was introduced here.
The source extension is enabled by default in the recipe.

The original research clones had older patch histories. New local `installed-assistant/` worktrees
were created from the verified pin and the current original eight recipe patches applied with
`git am`; no original framework/Settings/build-release branch was reset or rebased. A small pinned
Permission clone was added. The branch name is `user-installed-assistant-20261121`. The original
eight patch files are byte-for-byte unchanged. Four additional format-patches make twelve.

Recipe implementation commit: `4a95c682517b1c6adf5970a808f124a1d00e6675`.
Fixture/integration contract commit: `782f6d1b04ef6c93c5f71eaaaecb6b5d9c9db0c1`.
This record is committed with the following documentation update.

The manifest was read from GrapheneOS's pinned release, not assumed from clone HEADs. Its local
copy `/tmp/ballistic-manifest-2026110200.xml` has SHA-256
`150ae4ac808f279994fe36040883106c09fbd660f1cb3ccc5343cf011f1b04c2`.

| Project | Pinned base | Final research commit | Verified final tree |
| --- | --- | --- | --- |
| `build/release` | `6f3f4075803f96161d037b35c168d623bd2b0d4f` | `951ae450b0d5abaa0c842f4788eb0f3db0d9728e` | `1003e92470b9acc8b640e2eed46a5f218883bdf6` |
| `frameworks/base` | `ad133394d44339da17d691fd45d51afb161b94ae` | `8ae4e38b3c42a6b903138abd1f0d4c7be14d8575` | `f1de0a8f2f39713f1eeb96ff36f5110c79f776ce` |
| `packages/apps/Settings` | `b6ef57550748eb6f54ebab4914c6e630a20fd07a` | `00539d122a48575f4306662eca91bc8adc054436` | `2d627d4040439781e86e4211302c8e521f6c14b6` |
| `packages/modules/Permission` | `1539b4b9d7492b3bfac6a61f8413a6632a0cce56` | `d6c4a02884c031e0cb44cff740649f8b584265ba` | `ec850861b9eb89b19c145c2b28459462845becb2` |

`git am` produces different commit identities when committer metadata differs; the verified trees
and patch hashes below identify content. Frameworks 0006 was exported from `b282587afc24e932d215f2d878622315564f4219`;
0007, Settings 0002 and Permission 0001 are the final commits in their respective rows above.

## Pinned-source findings

- Framework `core/res/AndroidManifest.xml` now keeps `internal|privileged` and adds `role` for
  ACCESS_COMPUTER_CONTROL. In `PermissionService.kt`, role permission management is restricted
  to system/root/PermissionController; role status is not self-grantable by the ordinary app.
  `AppIdPermissionPolicy.kt` preserves role/runtime grant flags alongside protection grants.
- PermissionController `roles.xml`, `role-controller/.../model/Permission.java`, `RoleParser.java`
  and `role-controller/.../model/Permissions.java` provide the grant through the qualified ASSISTANT role,
  intersect requested permissions and revoke role flags on withdrawal. The optional declaration
  uses `minSdkVersion=10000, optionalMinSdkVersion=37`: optionalMin alone would retain the default
  unconditional minimum and could try to grant the original non-role permission on another image.
  Availability below 10000 requires the actual platform permission to be role/dangerous/AppOp
  grantable. Feature-off images do not acquire authority from this declaration.
- ASSISTANT is `requestable=false`; ACTION_ASSIST activity qualification and the default digital
  assistant Settings UI are supported. Managed profiles remain unavailable. The fingerprint was
  added to `RoleServicePlatformHelperImpl.computePackageStateHash` to reconcile existing holders
  after an OS upgrade even when their APK paths are unchanged. Real grant/revoke/update behavior
  still needs the device matrix; a Permission module update must carry this configuration patch.
- The existing AppOp session watcher did not establish complete role/permission live revocation.
  Added listeners cover role, permission, policy and package events; a withdrawal generation now
  spans pending consent as well as construction. Ordinary clients require both signer-bound
  switches even on DeviceConfig alternatives. Privileged vendor compatibility remains explicit.
  Global AppOp callbacks may have empty package names and USER_ALL; these close affected sessions
  conservatively. No callback-latency or race-safety claim is inferred from source inspection.
- The existing shared library and registration XML were not pulled into this product by the
  consent module. The new required dependency installs them; the new compile-only public module
  uses the existing droidstubs source output. Pinned Soong `java/droidstubs.go:setOutputFiles`
  (`250710f7f87acfbb8e3c517d90abde8b4a08fe1e`) confirms the default output is its generated stubs
  srcjar. Actual Soong generation and dependency compatibility still need the full-tree build.
- Pinned ART `runtime/hidden_api.cc:DetermineDomainFromDexLocation`
  (`6a459adafb78451393b2bfb45e805934df2a3d6b`) assigns `/system_ext/framework` jars the platform
  domain. This supports loading the wrapper rather than copying its implementation into the APK;
  it does not exempt the ordinary APK. No global hidden-API exemption was added. On-device library
  loading and invocation are not yet proven.
- EnhancedConfirmationService at the pin has dialer/SMS role restrictions, not ASSISTANT. Default
  app selection still consults the restriction API. No restricted-settings bypass was added;
  installer-specific behavior must be recorded on-device.

## Checks actually executed

All commands in this section ran locally; no full source sync or OS build ran on Wakeel. Resource
checks preceded source/tool downloads; the final checkpoint showed about 29 GiB free disk, 14 GiB
RAM, 9.1 GiB available RAM and almost-full 4 GiB swap. Work used existing research objects, sparse
disposable verification clones, one small Permission clone and standalone tools under `/tmp`.
The JDK was obtained with `apt-get download` and extracted with `dpkg-deb`, not installed system-wide.

1. **Passed:** original eight patches and final twelve patches applied with `git am` to the exact
   four pinned commits. Final check:

   ```bash
   python3 scripts/verify-patches.py /home/wakeel/src/ballistic-os-work
   ```

   The final run printed the four tree IDs above, passed rerun idempotence and rejected a deliberately
   untracked marker without removing it. Temporary clones were cleaned up. This proves patch
   application and the tested refusal, not compilation.

2. **Passed:** full public extension signature headers and both fixture Java sources compiled:

   ```bash
   python3 scripts/check-client-api.py \
     /home/wakeel/src/ballistic-os-work/installed-assistant/platform_frameworks_base \
     /tmp/ballistic-compile-contract/android.jar \
     --javac /tmp/ballistic-compile-contract/jdk/usr/lib/jvm/java-21-openjdk-amd64/bin/javac
   ```

   javac version: `21.0.13.1`. The script derives temporary headers from the entire checked-in
   `libs/computercontrol/api_extension/current.txt`; it strips annotations and compiles against the
   public SDK, then compiles both fixture Java sources. The negative assistant uses the same source
   with a separate manifest. This is a **signature/type contract check**, not a metalava, Soong,
   dex, manifest merge, APK-signing or runtime test. Headers and classes are deleted after the check.

   SDK source: `platform/prebuilts/sdk` at `0f07e8d60ab0aba46129e427101f96ba459a95c1`,
   `current/public/android.jar`, git blob `d27528a19e1fa5c3f021a97fd99923b5fa1277f8`, SHA-256
   `4f3d35e16d20fda03abdc7f81b49ab50010742fb5effc51b821b4b9646697ead`.
   Downloaded from the exact googlesource revision and decoded from `?format=TEXT`.

3. **Passed:** changed Kotlin files parsed/formatted with pinned prebuilts/build-tools ktfmt
   (`9b6c8c6a2f582a9d7817fd8275c8014959c60cc4`, `common/framework/ktfmt.jar`), then
   `--kotlinlang-style --dry-run --set-exit-if-changed` reported no changes. Jar SHA-256:
   `c57c3e34530e5754a3737814bb010fc8be5abff3e624d14fc4050d10bd52fd01`.
   This is not Kotlin type compilation or Robolectric execution.
4. **Passed:** `bash -n scripts/sync.sh scripts/build.sh`, Python AST parsing for the new helpers,
   fixture manifest XML parsing, and source/non-patch `git diff --check`. Format-patch files retain
   their required context-space lines and standard mail footer; a plain recipe diff whitespace
   check reports those as whitespace, so source diffs are checked instead of altering patch syntax.

## Not run and next host/device steps

| Validation | Status |
| --- | --- |
| Android image/framework/PermissionController/Settings compile | Not run |
| Actual metalava stubs and shared-library Soong packaging | Not run |
| Ordinary APK build/dex/signing, signature comparison and `/data/app` install | Not run |
| SettingsRoboTests (including new search/candidate tests) | Not run |
| VirtualDeviceServicesTests / PermissionControllerMockingTests compilation | Not run for this extension |
| Those instrumentation suites on device | Not run |
| Normal owner flow, target observation/input and all revocation/update cases | Not run |
| Matching-key OTA/recovery validation | Not run |

The parent owns the adequately provisioned build host and source sync. The parent reported
Ubuntu 24.04, 18 CPUs, 94 GiB RAM and 570 GB free, with source under `/srv/ballistic/gos` as
`ballistic-build`. No cloud command was executed by this implementation child. The user's current
instruction is to **retain that instance and storage**. This record creates no deletion or signing
instruction.

From the recipe on that host, apply with
`python3 scripts/apply-patches.py /srv/ballistic/gos` after sync. Preserve existing destination work
when copying the fixtures. The [integration contract](../assistant-integration.md#fixtures-and-build-host-commands)
contains executable `m` commands for the wrapper, actual public stubs, service/Settings/controller,
three fixture APKs, both instrumentation packages and SettingsRoboTests, followed by focused host
tests. The [build procedure](../build.md) covers vendor generation and the unsigned user image.
The [regression matrix](../regression-tests.md) contains separate instrumentation commands and
ordinary-owner flow checks. Review full-tree compile output before relying on any APK artifact path.

An ordinary assistant must be independently signed, verified under `/data/app`, chosen through
Settings and explicitly enabled alongside individual targets on the centralized searchable page;
system target consent remains separate. Use no `pm grant`, install `-g`, root, platform signature,
preinstallation, shell role assignment or test adoption to make that success flow pass. Record
installer restrictions, library behavior, observation/input, notification visibility, pending and
active withdrawal, signer/user/policy isolation, reinstall/reboot/OTA and privileged compatibility.
There are no new APK/image artifact hashes because those artifacts have not been built.

## Patch SHA-256

```text
3b465526c5a5d0dcaebd8acfa52b8966f69bffde1c832bd018b01c766a9070a8  patches/build_release/0001-computer-control-flags.patch
db665924cada95e075b84be8fd73a77381558caaee650bb7032c30bced876ffc  patches/build_release/0002-computer-control-consent-app.patch
8db8e22a2b2f0a8c7a343aee00a6d7b01f4bdb2c35316933ded32ede6dbf406b  patches/frameworks_base/0001-computer-control-user-allowlist.patch
d17b286564941042fa1ec1c279bee59c82999f882ace87f4f30f7b210fdbf53c  patches/frameworks_base/0002-computer-control-user-allowlist-api.patch
20035525b884028abe22a185d6b2638ba2a1041cafdf7d9bc0da304a30fee9e9  patches/frameworks_base/0003-computer-control-revocation-and-creation.patch
ba7d37bfb4b93620b3324b95a5e98e709835f1f92e970fd2a69b3aa6bd93cdc8  patches/frameworks_base/0004-computer-control-parameter-validation.patch
ebc339d4f1d65f03a5260112e7ae44b65810fed2ff6aadeb2b0798191acb9d7b  patches/frameworks_base/0005-computer-control-final-authorization.patch
1502dc4ad77ca31d2ceabba9d58a766cd53798c694469815d8ed8197f77d83f8  patches/frameworks_base/0006-computer-control-installed-assistants.patch
b9623db66b50c7cf0a8a2cd8e4744caddf4450c1d4e4b8b03cc0ababf2ca9e90  patches/frameworks_base/0007-computer-control-client-library.patch
b430c268c5245cbfc86fd80a266faa59cc264b22d4cff21b14b729efdbd81fff  patches/packages_apps_Settings/0001-computer-control-user-allowlist-ui.patch
ca8f0d0ab7fa33413f752c8f9ce66d6bd64a9b6c2f85d7cfa2c63200cebb6f58  patches/packages_apps_Settings/0002-computer-control-central-settings.patch
e69100026b842add1b7a6056c09782de2611328efe3213df416fbe71663c5dc0  patches/packages_modules_Permission/0001-assistant-computer-control-role.patch
```
