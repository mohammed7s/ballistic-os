# OS context and current decisions

Updated 21 November 2026. This is the handoff for the platform repository. App decisions and
agent development belong in [Ballistic](https://github.com/mohammed7s/ballistic).

## Scope

Build GrapheneOS from the tag in MANIFEST plus readable `git format-patch` files. Keep changes
small, generic and user-facing. No agent, policy engine or model host in the OS. No change to
keystore, verified-boot enforcement, attestation or GrapheneOS hardening is intended.

## Decisions

- GrapheneOS is the first platform integration target, not the identity of the app.
- Maintain a pinned source recipe and patch series, not the abandoned `ballistic-17` fork and
  local-manifest-overlay layout. An upstream submission may create a fork when needed.
- Computer Control uses signer-bound, per-user assistant/target lists alongside existing checks.
  Preserve assistant-role, permission, AppOp, device-policy and per-target consent checks.
- Settings and the consent editor must not become automation targets. Revocation and concurrent
  construction need explicit testing; source inspection alone does not establish safety.
- Existing SELinux policy permits the required system_server input path at the researched tag;
  this patch set does not add a sepolicy delta.
- Models and per-operation approval policy stay in the app. The abandoned provider-selection
  proposal is not an active milestone.
- AppFunctions needs separate caller-access work; Computer Control does not grant it.
- Production keys stay off rented build hosts. The recorded cloud-signing exception used
  disposable test keys for a test phone; it is not a production procedure.
- Public images and an OTA service are not established. The build script omits Updater.
- **8 Nov 2026: series re-cut from eleven patches to eight.** Fixes to earlier patches were
  folded into them, so no intermediate state carries the lock-order cycle. The three
  "Ballistic Authors" licence headers were removed to match GrapheneOS's headerless new files.
  The final source is otherwise identical. Mapping and checks:
  [log](log/2026-11-08-patch-series-recut.md).
- **8 Nov 2026: this repository stays generic.** The README and reviewer docs describe an
  owner-controlled gate for any assistant. Ballistic is named once, as the origin.

## Installed-assistant extension, 21 November 2026

**23 November: separate emulator build completed.** The owner authorized the app session to use
Contabo for this build. The existing patched source accepts `sdk_phone64_x86_64-cur-userdebug`
and reports Computer Control packaging enabled. Resume 2 exited 0 at 05:46:51 UTC, completing
162,044 build actions in 12:23:10. The image ZIP and wrapper/XML checks passed; transfer to the
ThinkPad has started. Boot and runtime validation are pending;
see [build evidence and live log paths](log/2026-11-22-emulator-build.md). The SDK emulator target
is for development, not a supported GrapheneOS device release.
The first two attempts stopped in bootstrap/analysis because the separate absolute external
output path was not supported by build-tool/module rules. Resume 2 uses a dedicated
source-relative `out-emulator-20261122`, leaving Pixel `out/` intact.

The authorized extension is implemented as four extension patches plus three build fixes (fifteen total, five repositories).
`ACCESS_COMPUTER_CONTROL` is now `internal|privileged|role`; PermissionController grants it only
to a qualifying selected assistant requesting it. Ordinary clients require both signer-bound owner
gates even if vendor allowlists match. Existing privileged grants and their vendor path remain.
Role selection never enables owner gates or target consent. No assistant is bundled/preselected.

Settings uses **one centralized Screen automation page**: selected assistant and its switch, a
searchable list of eligible installed targets with inline toggles, all fresh grants off. App-info
routes go there too. Per-target system consent remains separate. This supersedes the old separate
agent/target-page design. A signature-only candidate query excludes ineligible targets without
requiring their switches to be on.

Live role/permission/AppOp/policy/package changes are handled, pending consent is invalidated by
withdrawal, and PermissionController joins Settings/consent in the early protected-target guard.
Role reconciliation includes the OS fingerprint so existing holders receive updated role grants.
The installed system_ext wrapper and generated public compile stubs support ordinary clients
without global hidden-API exemptions. The minimal assistant/target fixtures exercise the contract;
the real app's Screen/Hands/model/policy adapters and AppFunctions remain out of scope.

Source and build contract: [assistant integration](assistant-integration.md). The first full-tree build found a
partition-dependency error during vendor helper preparation. Two appended packaging patches
corrected it. The resumed build completed vendor preparation and reached Settings compilation;
a third correction explicitly types the new switch callbacks. Compilation of the requested
platform/library and test modules and full unsigned OS packaging now pass as `2026112100`.
Focused Settings host tests passed 14 cases, with 3 assumption skips and no failures. The three separate
fixture APKs compiled after a Soong defaults correction and passed signature checks. Signing and verified ThinkPad delivery completed; device installation and execution remain
pending; see the [unsigned image record](log/2026-11-22-unsigned-image.md). See the
[cloud build record](log/2026-11-21-cloud-build-fixes.md). A lightweight public-SDK javac contract check passed; clean
application and source identities are in [the dated record](log/2026-11-21-installed-assistants.md).
At this pin, EnhancedConfirmationService does not protect assistant role selection; no bypass
is added. Record installer-specific behavior on-device rather than assuming accessibility rules.

## Recorded validation

The source tag is `2026110200`. The eleven-patch snapshot recorded at recipe commit `6b936cf`
(patch contents from reviewed `d02b997`) built as `2026110700`. The pre-extension eight-patch series
had the same final source apart from removed licence comments; it was not compiled itself.
The current fifteen-patch series adds the installed-assistant extension. Its requested platform
and test modules and unsigned image packages built on Contabo; host tests passed 14 cases with
3 assumption skips. Signing and ThinkPad verification passed; installation and device validation remain pending.
For that historical eleven-patch snapshot, compilation and signing passed. Focused Settings host
tests passed 11 cases with 3 assumption skips; instrumentation package compilation did not mean
its device tests ran.

The patched factory image was downloaded and verified, then flashed and relocked on the test
Pixel 10 Pro (`blazer`). The final flash record still leaves modified-build boot, displayed key,
installed build number, runtime regression checks and OTA testing pending. Do not summarize this
as a proven boot or functioning assistant. Earlier README claims that compilation was pending
are superseded by the dated records.

Evidence: [build/test record](log/2026-11-07-before-reorganization-regression-tests.md),
[flash record](log/2026-11-07-before-reorganization-flashing.md),
[test-key record](log/2026-11-07-before-reorganization-keys.md).
These are historical records, not assertions that their tmux jobs or cloud hosts are still live.

## Next platform work

**Cloud recovery, 21 November:** after finding process-hiding malware indicators, the owner
approved erasing the VPS disk. Contabo accepted the clean Ubuntu reinstall through its API;
the new SSH host identity and fresh baseline were verified. Dependencies and firewall setup
passed, the updated kernel booted, and the fresh source/build pipeline was launched. This is
not a completed build. Retain the VPS subscription.
See the [recovery record](log/2026-11-21-contabo-reinstall.md) and
[original evidence](log/2026-11-21-contabo-build-hold.md). Never reuse the discarded installation's
source or output as trusted build inputs.

1. Verify boot, build identity and expected public key on the already-flashed phone.
2. Run the focused runtime checks and account for instrumentation signing requirements.
3. Build the new role/library/Settings changes and ordinary fixtures, then validate the real client.
4. Prove matching-key recovery OTA behavior before designing automatic publishing.
5. Prepare an upstream discussion with clear threat model, patch scope and device evidence.

Do not infer authority to flash again from a dated test record. App integration must also satisfy
its [platform contract](https://github.com/mohammed7s/ballistic/blob/master/docs/PLATFORM.md).

## Open questions

- Will GrapheneOS accept an owner-managed Computer Control gate?
- The installed-assistant extension is now implemented experimentally; acceptance and runtime
  safety remain unverified. The earlier preference to discuss before implementation was superseded
  by the 21 November implementation authorization.
- Scope: this repository covers OS permissions only. How assistants behave in apps belongs to
  the assistant. Whether apps accept automation is for app and assistant developers to settle.
  The OS takes no side: the FAQ records what apps can see, with precedents, and the patches
  leave it as AOSP built it.
- Is the consent app already in GrapheneOS? The source at the tag says no; a 1 October 2026
  forum post reports it present after release 2026092500. Check on an unmodified device.
- Do all pending-construction/revocation and cross-user cases hold on-device?
- Do the independently signed fixtures satisfy the complete Settings/role/consent flow on-device?
- What separate AppFunctions access delta is justified?
- What image distribution, signing and update policy is appropriate if development becomes public?

Source facts: [FACTS.md](FACTS.md). Patch rationale: [patches.md](patches.md). Reviewer questions: [faq.md](faq.md).
Keep new decisions here and dated build/session details in [log/](log/README.md).

## Current signing and delivery, 22 November 2026

The owner requested cloud signing with the existing disposable test identity. The ThinkPad is
reachable with 77 GiB free. Cloud signing completed successfully at 06:49:06 UTC with the matching factory and AVB
identity. Temporary cloud key copies were removed. ThinkPad download, checksum/signature checks,
extraction and AVB public-key verification completed at 07:23:59 UTC. The sleep inhibitor was
released and 69 GiB remains free. The matching-key recovery OTA subsequently completed, the owner
confirmed recovery success, and ADB verified build `2026112100` booted with a locked bootloader
and the Computer Control shared library registered and present. The update sleep inhibitor is
also released. Assistant session execution, consent and revocation remain unverified on-device.
The transfer verifies checksums, the pinned factory signer and extracted AVB key, and does not
flash the phone. See [signing/delivery record](log/2026-11-22-cloud-test-signing.md).
The VPS and storage remain retained as requested.
