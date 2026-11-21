# Handover: enable user-installed Computer Control assistants

## Implementation status — 21 November 2026

Implemented as four additional patches on the original eight, against the same pinned tag.
The owner experience below includes the user's correction requiring one centralized, searchable
Settings page. See the [integration contract](assistant-integration.md),
[patch index](../patches/README.md) and [dated evidence](log/2026-11-21-installed-assistants.md).
Clean patch application and the lightweight public-SDK Java contract check passed. Full-tree
compilation, Android tests and device execution of this extension remain **not run**.
The original task and acceptance criteria below remain the validation requirements.

## Task

Implement an experimental OS extension that lets the owner install an assistant as a normal
APK and deliberately authorize it to use Computer Control. It must not require bundling the
assistant into the system image, platform-signing it, rooting the device, or using ADB to grant
its production permissions. Keep the implementation generic: no Ballistic package or signer
special cases.

Deliver the source patches, meaningful tests, updated documentation, and an exact app integration
contract. Validate as far as the available build/device environment permits; clearly separate
implemented, compiled, host-tested and device-tested status.

This task advances the open problem in the README and FAQ. Their earlier preference to discuss
the idea before writing a patch is historical context, not a reason to stop this implementation.
The work remains experimental and does not imply GrapheneOS endorsement or upstream acceptance.

## Read first and establish the baseline

- [Repository instructions](../CLAUDE.md), [README](../README.md), [current context](CONTEXT.md)
  and [roadmap](PLAN.md).
- [FAQ: user-installed assistants](faq.md#can-a-user-installed-assistant-use-this).
- [Patch index](../patches/README.md), [design](patches.md), [validation](regression-tests.md)
  and [build procedure](build.md).

The inspected baseline is GrapheneOS tag `2026110200`, with eight format-patches across
`build/release`, `frameworks/base` and `packages/apps/Settings`. Confirm MANIFEST, HEAD and the
working tree before editing; preserve subsequent work. Local research clones are under
`/home/wakeel/src/ballistic-os-work/`. They are not a full build tree, and their revisions may
differ from the recipe. Use verified work branches rather than treating them as authoritative.

An earlier eleven-patch form compiled and was signed/flashed on a test Pixel 10 Pro (`blazer`).
The current docs still leave boot identity and runtime Computer Control validation pending.
Do not infer a working session from that build or flash record.

## Intended owner experience

1. Install an eligible assistant normally.
2. Select it as the default digital assistant through the system Settings UI.
3. Open the one centralized **Screen automation** page in Android Settings. It displays the
   owner's chosen assistant and its automation switch; explicitly enable it. No Ballistic
   branding, default or preselected assistant is supplied.
4. Search the eligible installed target-app list on that same page by label or package name,
   and enable individual targets using inline switches. All fresh grants start off.
5. Complete the system's per-target consent flow when a session requests access.

Selecting the assistant alone must not bypass the owner switches or consent. An ordinary app
must not grant itself this authority. Keep the existing foreground/notification requirements.
Withdrawal must block pending requests and stop affected live sessions. Keep Settings and the
consent editor excluded as targets, including attempts through alternative allowlist paths.

Document any additional Android restricted-settings steps discovered during implementation.
Do not silently bypass them. Explain the actual exposure to a malicious assistant: authorizing
an app gives it substantial power inside approved targets; this is not a claim of zero risk.

## Implementation work

### 1. Verify and implement the role-based permission candidate

The proposed starting point is:

- In `frameworks/base/core/res/AndroidManifest.xml`, investigate adding the `role` protection
  flag to `android.permission.ACCESS_COMPUTER_CONTROL`, preserving its existing protection flags.
- In `packages/modules/Permission/PermissionController/res/xml/roles.xml`, investigate granting
  that permission to an eligible holder of `android.app.role.ASSISTANT` that requests it.
- Add the Permission module to the recipe's documented patch coverage and application flow.

These are hypotheses, not a verified two-line fix. Trace the pinned permission manager and
role-controller implementation. Prove that a normally installed, independently signed APK can
receive the grant, and determine grant/revoke behavior on role changes, reinstall, reboot and
module updates. Check how existing role holders receive the grant after an OS update. Verify
role eligibility and the supported Settings entry point rather than assuming a request-role
intent works at this tag.

Trace `ComputerControlAllowlistController`, session construction/publication and active-session
lifecycle. Do not remove assistant-role, permission, AppOp, device-policy, signer, per-user or
consent checks to make a test pass. Determine whether upstream listeners already close live
sessions after role/permission loss; add narrowly scoped handling if they do not. A final check
before publication alone does not prove live-session revocation.

Preserve existing privileged-client compatibility. A preinstalled app may retain a permission
through a separate grant path; it must still fail session authorization when its role is lost.
Also inspect existing DeviceConfig and special-agent paths so the documented owner experience
does not overstate what the combined policy enforces.

Keep this extension in separate, reviewable patch commits from the existing owner-gate work.
Decide whether the recipe applies it by default or supports an optional variant, document that
choice, and ensure the advertised sync command actually reproduces it. Do not silently rebase
to a newer GrapheneOS release as part of this task.

### 2. Resolve the app-facing client library

Investigate `com.android.extensions.computercontrol` at the pinned source revision. Establish:

- Whether it is installed and registered as a shared library on the resulting image.
- Whether a normal app can load and invoke it, including any hidden-API restrictions.
- The precise compile-time artifact/stubs, manifest declaration and runtime version checks.
- Whether its installable module must be added to the product configuration.

`adb shell pm list libraries` is a useful device check, but not proof that an app can use it.
A launcher statically linking its own copy is also not proof of a public shared library. Avoid
speculative build-module names or global hidden-API exemptions. Verify with a minimal ordinary
APK and document any remaining blocker rather than replacing this with privileged packaging.

### 3. Provide a minimal test client and app handoff

Use a small test-only assistant APK and a controlled target app to exercise the real API.
The assistant must be installed under `/data/app`, independently signed, and eligible for the
assistant role. It must not rely on `pm grant`, test-only permission shortcuts, platform signing
or privileged preinstallation for the successful user flow. ADB may install fixtures and collect
evidence; owner authorization must use the intended UI.

Provide reproducible build/install instructions, the required manifest entries, role eligibility,
library setup, session version/lifecycle requirements, denial behavior and cleanup steps.
Demonstrate observation plus an input action against the controlled target where device access
permits. Keep the test client small; no model integration is needed.

The separate Ballistic repo owns its real `Screen`/`Hands` adapters, task policy, UI and models.
Do not expand this task into implementing those adapters. Do not enable AppFunctions as a side
effect: its caller-access policy is a separate project.

## Acceptance and regression coverage

Add focused tests for the new permission path and lifecycle behavior, using the existing test
suites where appropriate. Device evidence must distinguish these cases:

- Fresh normal install: no role, no authority; selecting the role still leaves automation off
  until the owner gates and consent are satisfied.
- Authorized normal assistant: opens a version-5 session and observes/acts only on approved
  controlled targets, with required visibility and notification behavior.
- Missing permission declaration, wrong role, denied owner switch, denied target, missing consent
  and protected targets: denied through the appropriate enforcement path.
- Assistant switch, role removal, permission/AppOp withdrawal and owner-switch withdrawal:
  pending construction cannot publish unauthorized sessions; live affected sessions stop.
- Target withdrawal: access ends and saved approvals are handled consistently with existing policy.
- Reboot, same-signer update, uninstall/reinstall and different-signer replacement: no unintended
  authority inheritance. State the intended behavior for each and test it.
- Cross-user/profile isolation and managed-device policy remain enforced.
- Restricted-settings behavior is recorded for relevant installation paths; no accidental bypass.
- Existing privileged-assistant and Settings tests still pass; skipped tests remain labeled skipped.

Use appropriate unit/host tests for logic and race cases. Compile instrumentation tests separately
from running them. For unavailable environments, deliver exact commands and mark cases `not run`;
do not replace missing device evidence with a claim that the feature works.

## Build environment and boundaries

Wakeel (`wakeel-Latitude-5420`) was inspected for this handoff: i5-1145G7, four cores/eight threads,
about 14 GiB usable RAM, approximately 5 GiB available, a full 4 GiB swap, and only 7.8 GiB free
on the root filesystem. Recheck these changing figures before resource-heavy operations.
Do not launch a full source sync or OS build there. Use it for patch development and lightweight
checks. Plan an appropriately provisioned build host with at least 64 GB RAM and roughly 500 GB
SSD space; preserve existing outputs for development rebuilds.

The [previous measurement](log/2026-11-07-before-reorganization-regression-tests.md) was
36 min 8 s for an incremental patched rebuild and 23 min 3 s for signing/package generation on
a rented EPYC server. Budgeting 1–2 hours for a similar incremental build/package cycle is only
an estimate; framework/permission changes may invalidate more work. A cold build is different.
The old host's continued availability has not been verified.

Continue code, tests and documentation without waiting for infrastructure. If no suitable build
host is available, report that specific remaining dependency. Do not rent paid resources,
delete existing build outputs, flash/unlock/wipe a phone, or publish artifacts merely on the
strength of historical session authorization. Preserve key custody in [keys.md](keys.md).

## Deliverables

1. Reviewable format-patches against the pinned baseline, including the Permission module and
   any proven library packaging or lifecycle changes; verify application to a clean baseline.
2. Focused test changes and the minimal ordinary-app integration fixture/instructions.
3. Updated README, FAQ, context, roadmap, patch index/design and regression checklist. Replace
   obsolete “preinstalled only” statements with exact implemented behavior and validation status;
   keep historical records intact.
4. An app integration note with the concrete manifest/build/session contract and remaining app work.
5. A dated evidence record with source revisions, patch identity, commands, build/test results and
   artifact hashes where produced. Never include signing secrets.

Finish with a concise report: what changed, what the owner now does, what was actually tested,
what remains unverified, and the next executable step. Do not claim upstream acceptance, stock
Android compatibility, completed app integration or runtime safety based on compilation alone.
