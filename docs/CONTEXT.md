# OS context and current decisions

Updated 7 November 2026. This is the handoff for the platform repository. App decisions and
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

## Recorded validation

The source tag is `2026110200`. The eleven-patch snapshot recorded at recipe commit `6b936cf`
(patch contents from reviewed `d02b997`) built as `2026110700`.
Compilation and signing passed. Focused Settings host tests passed 11 cases with 3 assumption
skips; instrumentation package compilation did not mean its device tests ran.

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

1. Verify boot, build identity and expected public key on the already-flashed phone.
2. Run the focused runtime checks and account for instrumentation signing requirements.
3. Integrate an appropriately packaged assistant and validate the actual Computer Control client.
4. Prove matching-key recovery OTA behavior before designing automatic publishing.
5. Prepare an upstream discussion with clear threat model, patch scope and device evidence.

Do not infer authority to flash again from a dated test record. App integration must also satisfy
its [platform contract](https://github.com/mohammed7s/ballistic/blob/main/docs/PLATFORM.md).

## Open questions

- Will GrapheneOS accept an owner-managed Computer Control gate?
- Do all pending-construction/revocation and cross-user cases hold on-device?
- How should the assistant be packaged and permission-allowlisted for this development image?
- What separate AppFunctions access delta is justified?
- What image distribution, signing and update policy is appropriate if development becomes public?

Source facts: [FACTS.md](FACTS.md). Patch rationale: [patches.md](patches.md).
Keep new decisions here and dated build/session details in [log/](log/README.md).
