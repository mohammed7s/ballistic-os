# Contabo build hold — 21 November 2026

The owner authorized a cloud build and explicitly instructed us to retain the Contabo VPS and
its storage afterward. This supersedes earlier instructions to delete paid instances. No flash,
wipe or new signing identity is authorized by the build request.

## Preparation and stopped work

Host `vmi3733172` reported Ubuntu 24.04, 18 logical CPUs, 94 GiB RAM and a roughly 581 GiB root
filesystem. Dedicated SSH public-key authentication worked. Private SSH and OS signing keys
were not uploaded, and agent forwarding was not requested.

Build dependencies and Node 24/Yarn were installed, and a non-sudo `ballistic-build` account was
created. Source initialization under `/srv/ballistic/gos` verified the GrapheneOS manifest tag
`2026110200` using the expected release-signing identity, then began a shallow source sync.
The sync reported checkout/configuration failures despite ample memory and inodes. It did not
finish. No patches were applied remotely, and no OS compilation or image generation began.

The parent stopped `ballistic-bootstrap-20261121.service`; `systemctl is-active` returned
`inactive`. The VPS and disk remain intact and running. Source downloaded onto this host must
not be reused as a trusted build input after recovery.

## Observed indicators

During investigation of the failed commands, kernel AppArmor logs reported programs attempting
to load `/usr/local/lib/libcommon.so`, including at boot before our dependency installation.
Read-only checks through the existing SSH session then reported:

- `/usr/local/lib/libcommon.so`: 7,064-byte ELF shared object, root-owned, with modification and
  birth timestamps on 6 November. SHA-256:
  `77c0c768861ba1896fa9c54ca6310c4797ecf0b0c2f14338f390694b542aa211`.
- Both `/proc/1/maps` and the interactive shell's process maps contained that library.
- Its exported functions include `readdir` and `readdir64`. Static disassembly shows filtering
  of `/proc` directory entries by process name. Its read-only data contains `16`, `/proc`,
  `/proc/self/fd/%d` and `/proc/%ld/comm`.
- `/etc/profile.d/libbase.sh` (342 bytes),
  `/etc/systemd/system/system-helper.service` (154 bytes) and `/var/tmp/snap` (4,510,496 bytes)
  were also present. These were not created by our build setup.
- `/etc/ld.so.preload` appeared empty when read, despite the already-loaded library. Its
  reported modification time changed during this investigation without a write by us.

The filename, process-filtering behavior and companion paths match indicators described in
an [independent DIICOT analysis](https://blog.efespain.com/capitulo-24/). This is strong evidence
of a compromised host. The exact entry point, operator, compromise time and malware family
have not been established. Timestamps and command results from a potentially compromised
running system are evidence to investigate, not a complete forensic account.

No suspicious binary was deliberately executed for analysis. Inspection used metadata,
strings, ELF symbols/disassembly and process maps. The loader had already injected the library
into host programs. No image from this environment may be treated as trusted or signed.

## Recovery boundary

The parent asked the owner to approve reinstalling Ubuntu on the same VPS and to identify any
other data needing preservation. Reinstallation erases its current disk contents and therefore
requires that decision; it does not require cancelling the VPS subscription. At the time of
this record, that approval is pending. No reinstall or destructive cleanup has occurred.

After an approved clean reinstall: verify the new SSH host key through the provider, configure
key-based access and restricted ingress, check the clean baseline, bootstrap dependencies and
fetch verified sources afresh. Then apply recipe `1beb727fa4afec3844fb562069de81e0facd58e5`
or its reviewed successor and follow [assistant integration](../assistant-integration.md).
Keep signing keys off the cloud host. Local patches, fixtures and their source-level verification
remain available on Wakeel and in the pushed repository; Android build and device checks remain
outstanding.
