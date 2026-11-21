# Contabo recovery and build preparation — 21 November 2026

Following the [compromise indicators](2026-11-21-contabo-build-hold.md), the owner explicitly
approved reinstalling Ubuntu and confirmed no other disk contents needed preserving. The
subscription must remain active. No new server was purchased and no cancellation was requested.

## Provider operation and identity

Contabo API authentication succeeded from Wakeel using credentials supplied through secure
input fields. In this account the current new-panel password also authenticated to the API;
earlier advice that a separate password was necessarily required was incorrect. Credentials
and access tokens remain outside Git and were not uploaded to the VPS.

Read-only API checks identified instance `203733172`, name `vmi3733172`, IPv4 `5.253.233.224`,
plan Cloud VPS 18 (2026), region EU. The approved reinstall used the standard `ubuntu-24.04`
image `d64d5c6c-9dda-4e38-8174-0ee282474d8a`. An initial request was rejected because the
SSH public key appeared in both API parameters and cloud-init. Removing the redundant
cloud-init authorized-key entry produced an accepted reinstall request; provider status
subsequently moved through `installing` to `running`.

A newly generated server SSH host key was supplied through the authenticated provider API.
Its public fingerprint is `SHA256:s1hAEvIYCb8T6qTQhaID6WH5nGzsOjXihVDcRTnE1Z8`.
SSH connections require this exact key using a dedicated known-hosts file on Wakeel,
`/home/wakeel/.cache/ballistic-contabo/known_hosts`. The prior server key was rejected while
reinstallation was still underway. Client SSH private keys and OS signing keys were not sent.
The newly generated server host key is distinct from both.

## Fresh-system observations and preparation

The replacement reports Ubuntu 24.04.5 LTS, 94 GiB RAM and a 581 GiB root filesystem, initially
using only 1.8 GiB. Our installation marker was present. The previously observed library,
shell hook, persistence service and `/var/tmp/snap` were absent; `/etc/ld.so.preload` was absent
or empty, and the library was absent from PID 1 and the shell's memory maps. `dpkg -V` reported
no changes for openssh-server, libc6, coreutils and bash. These checks are a fresh baseline,
not an exhaustive forensic guarantee.

Effective SSH settings were public-key enabled, password and keyboard-interactive authentication
disabled, and root login restricted to keys. A host UFW firewall denies incoming connections
by default and rate-limits SSH on port 22 for IPv4 and IPv6. No paid provider firewall add-on
was ordered.

Provider cloud-init reported a bootcmd error: its final `pkill -HUP sshd` ran before an SSH
daemon was available. Later SSH checks passed. Provider package updates also waited on
networkd readiness despite an operational, routable interface. Stopping the readiness helper
allowed initialization to complete; the network daemon itself was not stopped. A service
override limits future readiness waits to 30 seconds (40-second service start limit and
5-second stop limit), without changing addresses or routes.

Host preparation finished with `rc=0` at `2026-11-21T12:03:32Z`. It installed build dependencies,
Node 24 and Yarn, created the non-sudo `ballistic-build` user, and retained the owner instruction
in `/srv/ballistic/KEEP_SERVER.txt`. A reboot was requested to load the updated kernel before
starting source work.

## Build recipe and planned execution

Recipe snapshot: `cb3ec7a`, containing the twelve-patch implementation at `1beb727` and subsequent
incident/authorization documentation. Archive SHA-256, verified on both machines:
`6c11af6d94b6732d005d5da077df6fc9781e53f96a64a5faedaecdb054a34539`.

Remote paths:

- Recipe: `/srv/ballistic/recipe`
- Fresh source: `/srv/ballistic/gos`
- Preparation log: `/srv/ballistic/logs/prepare-cleanhost-20261121.log`
- Build runner: `/srv/ballistic/build-cleanhost-20261121.sh`
- Intended build log: `/srv/ballistic/logs/build-2026112100.log`
- Intended exit-status record: `/srv/ballistic/logs/build-2026112100.exit`

The runner verifies manifest tag `2026110200`, syncs fresh sources with eight fetch workers,
applies the twelve patches and compares all four patched trees with the implementation record.
It then prepares vendor files, builds platform/library/test targets, runs focused Settings host
tests and builds unsigned `blazer-cur-user` packages as `2026112100` with 18 build workers.
Ordinary fixture APKs are built after OS packaging so their staging outputs cannot contaminate
the initial image; the target-files ZIP is explicitly checked for their absence.

After reboot, kernel `6.8.0-151-generic`, Node `v24.22.3` and Yarn `1.22.22` were confirmed.
Key-only SSH, active firewall and absence of the known compromise indicators were rechecked.
The provider bootcmd error still marks cloud-init's network stage failed; its final stage is
active/exited and connectivity works. This remains a recorded provider configuration warning.

The pipeline was started under the unprivileged account as
`ballistic-build-2026112100.service` (invocation `20e04c67294b4d13858e6b52a627fa47`).
This records a launch, not successful completion. No compilation, host-test or device success
is claimed here. Signing and ThinkPad delivery follow successful build verification; flashing
remains separately authorized.
