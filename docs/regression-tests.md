# Patched build 2026110700: validation record

Source: tag `2026110200` plus the eleven-patch snapshot from recipe commit
`6b936cf` (patch contents unchanged from reviewed `d02b997`). Exact provenance,
patch snapshot, applied revisions and logs are on instance 59466158 in
`/home/build/ballistic-patch-build-2026110700/`.

## Compilation: passed

Supervisor job `ballistic-patched-2026110700` finished at 2026-11-07 01:09:56 UTC,
`rc=0 stage=complete`, after 36 minutes 8 seconds including finalization.
Used `m -j32 target-files-package otatools-package`, preserving existing outputs,
vendor files and baseline release `2026110600`.

Unsigned artifacts in `/home/build/gos/releases/2026110700/` were verified with
`sha256sum -c` against the job's `SHA256SUMS`:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `blazer-target_files.zip` | 4543948875 | `1adb63038677020781fdb2b373adf83b199ba6b6a91a63b3f15c41c2fffd008c` |
| `blazer-otatools.zip` | 536798276 | `be89d856cced592907e265e8a474b167a4ff36e49b7438a696e5049ccefe34f7` |

## Signing: running

Started 01:11:04 UTC using the existing cloud test keys documented in `keys.md`.
No new keys were generated. `sign.sh`, `sign.log`, and `sign-status.txt` are in the
job directory. The signing wrapper was updated for the noexec `/dev/shm` fix.
Signed outputs belong in `releases/2026110700/release-blazer-2026110700/`.

## Android regression tests: pending

The separate `test-patched-2026110700` tmux job starts only after successful OS
compilation. Script/log/status: `tests.sh`, `tests.log`, `tests-status.txt` in the
job directory. It preserves the recorded build number and timestamp, uses `-j32`,
and first compiles `VirtualDeviceServicesTests`, `SettingsRoboTests`,
`atest-tradefed`, and `tradefed`. It then attempts only these host tests:

```sh
atest --host -t --disable-upload-result \
  SettingsRoboTests:ComputerControlAgentPageProviderTest \
  SettingsRoboTests:ComputerControlAutomationTest
```

No test pass is claimed until the result report confirms execution and counts.
Compilation of a test package does not mean those tests ran.

`VirtualDeviceServicesTests` is Android instrumentation, not a host test. After a
compatible patched test device is available, run its focused classes:
`ComputerControlUserAllowlistTest`, `ComputerControlAllowlistControllerTest`, and
`ComputerControlSessionProcessorTest`. Account for platform-signature matching;
never install an APK signed with source-tree test keys as though it matched the
cloud-signed platform key.

## On-device behavior: not validated

No flashing or unlocking is authorized by these build/test jobs. Obtain the
owner's final backup-and-go confirmation first. After installation, execute the
runtime checklist in `patches.md`, including empty defaults, user/signer binding,
protected targets, v4 rejection/v5 foreground requirements, Allow once/Always
allow, revocation while consent or construction is pending, role/AppOp/permission
withdrawal, user isolation, persistence, and concurrent Back/creation/revocation.
Compilation and host tests alone do not validate Computer Control on-device.
