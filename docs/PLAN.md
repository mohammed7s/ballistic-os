# Platform roadmap

This repo delivers the OS capability provider. The assistant has its own
[app roadmap](https://github.com/mohammed7s/ballistic/blob/master/docs/PLAN.md).
Historical app-plan OS steps 4, 5, 9 and 10 now live here.

## 1. Build, sign and verify the development platform

The baseline and patched images have compiled and been signed; patched flashing/relocking is
recorded. Complete boot/build/key verification and matching-key recovery OTA testing.
Keep source provenance, patch snapshot, artifact hashes and signing identity with every result.
Deliverable: a reproducible build and validated installation/update path.

## 2. Validate the Computer Control gate

The patch set is implemented (fifteen patches after the 21 November extension and build fixes).
Complete device tests for empty defaults, per-user/signer
binding, target exclusions, consent, version requirements, revocation and concurrent construction.
Existing source evidence answers the sepolicy question; runtime checks still matter.
Deliverable: repeatable device results, including denied and revoked access, not compilation alone.

## 3. Integrate the assistant

Build and run the ordinary assistant and controlled-target fixtures using the
[integration contract](assistant-integration.md). The role permission, shared wrapper and centralized
Settings page are implemented; full-tree compilation and runtime validation of the extension remain.
Verify default-off gates, consent, observation/input, notification/foreground requirements, Stop,
live/pending revocation, upgrade/reinstall and cross-user cases. Then coordinate the real app's
Computer Control adapter in its own repository. No production privileged packaging is required.
Deliverable: an independently signed `/data/app` assistant operating an approved controlled target
through owner UI alone, with evidence. Agent logic and model hosting remain outside this repo.

## 4. Maintain the patch series and updates

For each chosen GrapheneOS tag, apply the patch series, review conflicts, build and run platform
regressions plus the app capability/injection suites. Build automation and OTA publishing are
future work; no `ota.sh` or CI rebase bot is currently shipped here. Validate an update path and
release policy before enabling publication.
Deliverable: traceable updates with test evidence and a recovery procedure.

## 5. Upstream proposal

Ask about an owner-managed Computer Control allowlist, how a user-installed assistant could be
given access with deliberate owner authorization (the experimental extension in faq.md),
and expected integration with future third-party assistant APIs. Bring reviewed patches and
runtime evidence. Ask early; do not assume acceptance. Submit the Computer Control gate as a
small independent proposal, with no assistant or model bundled into the ask.

AppFunctions is a separate design-only follow-up. Provider selection and an OS policy service
are dropped from the active plan. No signing, attestation spoofing or hardening exception is
part of the upstream proposal.

## 6. Distribution decision

Decide whether OS builds remain personal, become a supported public development channel, or
become unnecessary for users once supported platforms expose suitable APIs. Image distribution,
production keys and update infrastructure are separate from distributing the assistant APK.
