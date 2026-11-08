# Working in ballistic-os

Read README.md, docs/CONTEXT.md and docs/PLAN.md; consult patches/README.md for apply order and
docs/patches.md for design. This repo owns OS gates, privileged packaging, build/sign/flash/OTA
and platform tests. The Ballistic app, models and policy live in the separate ballistic repo.

Keep source changes small and generic. Preserve GrapheneOS hardening. Maintain a pinned source
recipe plus format-patch files, not an undocumented fork layout. Do not claim runtime validation
from compilation or a successful flash. Current decisions go in docs/CONTEXT.md; dated commands,
logs, hashes and machine paths go in docs/log/. Never commit private keys or passphrases.
Historical session authorization is not authorization for a new destructive device operation.
