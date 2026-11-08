# Platform validation checklist

Record results per source tag, patch snapshot, signing identity and device. Use `passed`,
`failed`, `skipped` or `not run`; never count test compilation or assumption skips as passes.
The [7 November build/test record](log/2026-11-07-before-reorganization-regression-tests.md)
contains the original measurements. It recorded 11 focused Settings host passes and 3 skips;
on-device Computer Control validation remains pending.

## Build and host tests

Compile the image and relevant test packages. In the configured source environment, the recorded
focused Settings invocation was:

```bash
atest --host -t --disable-upload-result   SettingsRoboTests:ComputerControlAgentPageProviderTest   SettingsRoboTests:ComputerControlAutomationTest
```

Ensure adb and Tradefed prerequisites are available. Keep test-runner errors separate from test
failures. `VirtualDeviceServicesTests` is instrumentation, not a host test; compilation does not
execute it. Confirm test APK/platform signing compatibility before any installation.

## Device checks

- Verify boot, installed build, expected public key and locked bootloader.
- Test empty defaults, user and signer binding, uninstall cleanup and persistence.
- Verify protected targets and version-4 rejection/version-5 foreground requirements.
- Exercise Allow once and Always allow without weakening AppOp or role checks.
- Revoke grants during consent and construction; verify no unauthorized session publishes.
- Exercise permission, role, AppOp and device-policy withdrawal, cross-user isolation and
  concurrent Back/creation/revocation.
- Run focused `ComputerControlUserAllowlistTest`, `ComputerControlAllowlistControllerTest` and
  `ComputerControlSessionProcessorTest` on a compatible device where feasible.

Detailed expected behavior and race cases are in the [reviewer guide](patches.md), §9.
The recorded build used the eleven-patch form of the series. The current eight patches have the
same final source apart from removed licence comments and have not been compiled themselves.

## Integration and updates

Validate the actual assistant package and client adapter, not only service test doubles. Run the
app capability and injection suites with appropriate real approval tests. Check access revocation
and Stop. Confirm matching-key OTA installation and recovery separately from factory flashing.
Store results under [log/](log/README.md), with failures and untested cases visible.
