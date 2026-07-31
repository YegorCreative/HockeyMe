# Forge Fitness Release Checklist

## Release decision

- [ ] A release owner is named.
- [ ] Scope contains no unreviewed feature work.
- [ ] Critical and High items in `PLATFORM_AUDIT.md` are resolved or formally
  accepted.
- [ ] `KNOWN_LIMITATIONS.md` is reviewed by Product, Engineering, Security, and
  Support.

## Environments

- [ ] Debug configuration cannot target Production.
- [ ] Staging configuration cannot target Production.
- [ ] Production configuration targets the approved production project.
- [ ] No configuration file contains a service-role key.
- [ ] Staging and Production credentials are stored in protected CI
  environments.
- [ ] App bundles contain the expected environment configuration.
- [ ] Non-production indicators never appear in Production.

## Backend

- [ ] Full migrations replay from an empty staging database.
- [ ] Supabase database lint passes.
- [ ] Migration ordering and checksums are reviewed.
- [ ] All public tables have RLS enabled.
- [ ] Anonymous REST and RPC access is denied except explicitly public reads.
- [ ] Two-organization authenticated RLS matrix passes.
- [ ] Ownership transfer and invitation replay tests pass.
- [ ] Canonical exercise count and identifiers are verified.
- [ ] Backup restoration is tested.
- [ ] Rollback SQL and application rollback version are identified.

## iPhone

- [ ] Debug and Release simulator builds pass with warnings as errors.
- [ ] Unit and UI tests pass.
- [ ] Offline launch, reconnect, retry, and pending workout synchronization are
  manually tested.
- [ ] Authentication, onboarding, workout completion, and sign-out are tested
  with staging identities.
- [ ] VoiceOver, largest Dynamic Type, Increase Contrast, and Reduced Motion
  passes are complete.
- [ ] Privacy manifest and nutrition labels match actual behavior.

## Mac

- [ ] Live authenticated repository adapters are implemented.
- [ ] Debug and Release builds pass with warnings as errors.
- [ ] Mac tests pass.
- [ ] Full Keyboard Access and VoiceOver passes are complete.
- [ ] Tables are tested with production-scale staging fixtures.
- [ ] Signing, hardened runtime, notarization, and distribution are verified.

## Observability and operations

- [ ] Crash and MetricKit diagnostics are visible to the operations team.
- [ ] Logs contain no credentials, tokens, emails, names, notes, or request
  bodies.
- [ ] Authentication, workout sync, invitation, and RLS-denial alerts are
  configured.
- [ ] Support escalation and incident contacts are current.
- [ ] Rollback, backup, recovery, and breach procedures have been rehearsed.

## Final commands

Run the exact build, test, lint, migration, database-lint, documentation, and
secret-scanning commands in `TESTING_GUIDE.md`. Attach results to the release
record.

## Approval

- [ ] Engineering
- [ ] Security
- [ ] Product
- [ ] Operations
- [ ] Release owner
