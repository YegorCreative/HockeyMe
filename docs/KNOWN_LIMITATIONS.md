# Known Limitations

## Release blockers

1. The macOS Coach app has no live authenticated repository adapter.
2. The complete authenticated two-organization staging RLS matrix has not been
   executed in this workspace.
3. Staging invitation delivery and replay protection require external provider
   configuration and verification.
4. Apple signing, provisioning, notarization, and distribution credentials are
   not available locally.

## High-priority limitations

- Cached data has no user-visible freshness timestamp.
- Organization-wide optimistic concurrency is not implemented.
- Sign-out cache and pending-write disposition needs an approved product
  policy.
- Production-scale Instruments baselines do not yet exist.
- Repository interfaces are concrete in several iOS features, increasing test
  and cross-platform integration cost.

## Functional boundaries

- Parent and Forge Admin experiences remain outside the Mac Coach target.
- Mac ownership transfer and live role changes remain guarded.
- Exercise selection in Mac Developer Mode is in-memory only.
- Recovery and compliance values remain unavailable when not supported by a
  repository model.
- No medical or readiness interpretation is generated.

## Testing limitations

- Automated UI coverage is intentionally narrow.
- VoiceOver, rotor, Full Keyboard Access, Increase Contrast, and maximum Dynamic
  Type require manual release passes.
- Database tests require a dedicated staging Supabase project.
- Email delivery tests require a staging transactional-email provider.
- Network fault injection is not part of the current simulator suite.

## Offline limitations

- Profile, program, exercise, testing, and organization caches can be used
  offline, but their age is not displayed.
- Workout and testing result queues have idempotent conflict handling.
- Program and organization editing do not support offline mutation queues.
- A failed cache write does not interrupt the online workflow and is not yet
  exposed through internal diagnostics.

## Operational limitations

- TestFlight and Mac distribution pipelines require external Apple secrets.
- Supabase backup restoration has documentation but no recent recorded staging
  drill.
- Analytics is privacy-respecting and optional; it is not a substitute for
  database audit logs.
