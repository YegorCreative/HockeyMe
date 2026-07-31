# Forge Fitness Platform Audit

## Executive summary

Forge Fitness has strong safety fundamentals: environment-specific
configuration, Debug-only mock systems, privacy-safe structured logging,
production-shaped models, RLS-first backend authorization, offline write
queues, warnings-as-errors, and native iOS and macOS targets.

The platform is not ready for production organizations yet. The principal
blockers are incomplete live macOS repository integration, unexecuted staging
RLS verification, and offline caches that do not communicate freshness or
conflicts to users.

Audit date: July 30, 2026.

## Scope and method

The audit reviewed:

- both Xcode targets and their dependency graph;
- application bootstrap, navigation, and environment selection;
- service, repository, cache, synchronization, and ViewModel implementations;
- Swift concurrency and task lifetimes;
- Supabase migrations, RLS assumptions, privileged functions, and scripts;
- accessibility and Design System primitives;
- unit and UI coverage;
- release, security, testing, deployment, and operations documentation.

Static inspection was paired with warnings-as-errors builds, test execution,
SwiftLint, and project validation. Instruments traces against representative
production-scale data were not available; performance findings are therefore
limited to demonstrated code-path risks.

## Critical findings

### C-1 — macOS has no live authenticated repository adapter

The Mac Debug experience is functional through in-memory models, but configured
Staging and Production builds intentionally remain unavailable. Shipping the
Mac target would not provide a real Coach workflow.

Recommendation: implement adapters for authentication, athlete, programming,
testing, and organization repositories, then run the two-organization RLS
matrix from the Mac client.

### C-2 — staging security validation remains incomplete

The migration history contains extensive RLS policies and hardened
`security definer` functions with explicit search paths. However, the complete
Phase 6.1 authenticated matrix has not been replayed against a dedicated,
empty staging project in this workspace.

Recommendation: treat staging migration replay, database lint, REST/RPC role
matrix, invitation replay tests, and anonymous-denial tests as release gates.

## High findings

### H-1 — offline cache freshness is invisible

Repositories fall back to cached profiles, workouts, exercises, testing, and
organization context, but returned domain values contain no source timestamp,
age, or stale indicator. The user cannot tell cached data from fresh data.

Recommendation: wrap reads in a `RepositoryValue<Value>` carrying source,
cached-at, and synchronization state. Display the existing sync-status
component without redesigning screens.

### H-2 — conflict handling is last-write-oriented and narrow

Workout sets are idempotent by UUID and testing results replace the same
session/metric pair. Broader profile, program, organization, and prescription
conflicts do not carry server versions or ETags.

Recommendation: add `updated_at` preconditions or version columns to mutable
aggregate roots before multi-editor organization pilots.

### H-3 — concrete dependencies limit isolation and Mac reuse

Most ViewModels depend on concrete Supabase-backed classes. Debug injection
works through alternate initializers, but protocol boundaries are inconsistent
and the Mac app requires a separate facade.

Recommendation: introduce narrow repository protocols at feature boundaries
and compose live/mock implementations at bootstrap.

### H-4 — user cache lifecycle is not explicitly tied to sign-out

User-specific cache filenames are isolated by UUID and use atomic protected
writes, but there is no documented purge policy for shared devices. Pending
offline writes complicate safe deletion.

Recommendation: define a sign-out policy that attempts synchronization, asks
before discarding pending work, and clears readable user caches after successful
sign-out.

### H-5 — production-scale performance has not been measured

Current datasets are small. No Instruments baselines exist for 500+ athletes,
large programs, multi-season testing histories, or long workout histories.

Recommendation: establish signposts and performance fixtures, then record
launch, table filtering, navigation, memory, and decoding baselines on supported
hardware.

## Medium findings

### M-1 — sequential programming graph loads can become N+1

Program detail loading traverses weeks, workouts, and prescriptions through
sequential queries. This is acceptable for current fixtures but will scale
poorly for large programs.

Recommendation: measure on staging and replace with a versioned aggregate RPC
or nested read if latency exceeds the release budget.

### M-2 — error mapping was inconsistent

Several ViewModels displayed raw localized repository errors and treated
cancellation as failure. Phase 10 adds `AppErrorPresentation`, applies it to
primary athlete, workout, exercise, and coach loading paths, and prevents
cancellation alerts.

Remaining work: migrate editor and organization ViewModels to the same mapping.

### M-3 — reconnect synchronization could overlap

Connectivity and foreground/manual operations could start concurrent queue
flushes. Phase 10 adds `SynchronizationGate` and transition-only connectivity
callbacks. Workout and testing synchronization now share one active pass per
repository.

### M-4 — large derived collections are recalculated on access

Several views filter small arrays in computed properties. This is appropriate
today. If production profiles show frame regressions, move normalization and
sorting into ViewModels and debounce search input.

### M-5 — accessibility verification is mostly structural

The Design System uses semantic colors/fonts and key controls have labels.
Automated UI coverage checks authentication controls, but complete VoiceOver,
Full Keyboard Access, rotor, Increase Contrast, and largest Dynamic Type manual
passes are outstanding.

### M-6 — repository cache failures are intentionally swallowed

Cache-write failures do not block online workflows, which is appropriate, but
they are not surfaced as privacy-safe diagnostics. Offline reliability can
silently degrade.

Recommendation: emit non-sensitive cache-write health events and expose them in
internal diagnostics.

## Low findings

### L-1 — legacy `ObservableObject` remains widespread

The project consistently isolates ViewModels to `@MainActor`; migrating to the
Observation framework is optional and should occur feature-by-feature.

### L-2 — some formatter instances are created per conversion

A few timestamp helpers construct ISO 8601 formatters repeatedly. Network and
database latency currently dominate. Optimize only after profiling identifies
formatter allocation as material.

### L-3 — Mac exercise choices are a Debug workspace projection

They use supported model fields and do not persist, but the live Mac adapter
should source them from `ExerciseService`.

## Architecture health

- Domain models are simple and Codable where persistence requires it.
- Repository ownership is understandable, but protocol abstraction is uneven.
- Main-thread UI state is consistently protected by `@MainActor`.
- Long-lived authentication and timer tasks are cancelled.
- Offline storage is actor-isolated and uses atomic writes.
- Navigation has explicit role boundaries; backend RLS remains authoritative.
- Debug mock implementations are compile-time isolated.
- Shared Design System tokens now support UIKit and AppKit.

## Security health

- No service-role key is present in client code.
- Publishable keys are treated as configuration, not authorization.
- Logs reject credential, token, email, name, note, URL, and body metadata.
- Debug and Staging reject the production Supabase host.
- Privileged provisioning and invitation functions are server-only.
- RLS must still be proven against dedicated staging identities before release.

## Performance changes made

- Coalesced concurrent workout/testing queue synchronization.
- Limited reconnect work to offline-to-online transitions.
- Removed manual duplicate invalidation from exercise loading by publishing the
  actual backing collection.
- Preserved lazy SwiftUI containers and native macOS tables.

No speculative decoding, table, or chart rewrites were made without evidence.

## Overall assessment

Engineering health: 78/100.

Production readiness: approximately 70%. The iPhone architecture is suitable
for a controlled staging pilot after security validation. The macOS target is
not production-functional until live repository adapters exist.
