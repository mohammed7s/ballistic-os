# Platform roadmap

This repo delivers the OS capability provider. The assistant has its own
[app roadmap](https://github.com/mohammed7s/ballistic/blob/main/docs/PLAN.md).
Historical app-plan OS steps 4, 5, 9 and 10 now live here.

## 1. Build, sign and verify the development platform

The baseline and patched images have compiled and been signed; patched flashing/relocking is
recorded. Complete boot/build/key verification and matching-key recovery OTA testing.
Keep source provenance, patch snapshot, artifact hashes and signing identity with every result.
Deliverable: a reproducible build and validated installation/update path.

## 2. Validate the Computer Control gate

The eleven-patch set is implemented. Complete device tests for empty defaults, per-user/signer
binding, target exclusions, consent, version requirements, revocation and concurrent construction.
Existing source evidence answers the sepolicy question; runtime checks still matter.
Deliverable: repeatable device results, including denied and revoked access, not compilation alone.

## 3. Integrate the assistant

Provide the privileged package/permission configuration required by the client and retain all
role and consent requirements. Coordinate with the app repo's Computer Control adapter.
Deliverable: an app-owned task through the platform session on the physical phone, with approval,
Stop and revocation tested. Agent logic and model hosting remain outside this repo.

## 4. Maintain the patch series and updates

For each chosen GrapheneOS tag, apply the patch series, review conflicts, build and run platform
regressions plus the app capability/injection suites. Build automation and OTA publishing are
future work; no `ota.sh` or CI rebase bot is currently shipped here. Validate an update path and
release policy before enabling publication.
Deliverable: traceable updates with test evidence and a recovery procedure.

## 5. Upstream proposal

Ask about an owner-managed Computer Control allowlist, the preferred privileged-assistant path,
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
