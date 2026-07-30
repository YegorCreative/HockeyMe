# Forge Fitness Architecture

## System overview

Forge Fitness is a native SwiftUI iOS client backed by Supabase Auth and
PostgreSQL. The iOS app follows MVVM:

- `Views` render state and dispatch user actions.
- `ViewModels` own presentation state and structured-concurrency tasks.
- `Backend` services and repositories are the only database boundary.
- `Models` are transport-independent domain values.
- `AppRouter` restores authentication and selects athlete or coach navigation.

The publishable Supabase key is bundled in `SupabaseConfig.plist`. It identifies
the project but grants no privileged access; PostgreSQL RLS is the authorization
boundary. The service-role key is restricted to admin CLI workflows.

## Data flow

Authentication is restored before role routing. Coaches are detected through
`public.coaches`; athletes are routed through profile onboarding when required.
The athlete training plan is loaded through `get_active_training_plan`, which
returns the assignment, weeks, workouts, prescriptions, and completion state in
one request. Writes use normal table APIs and are validated by RLS.

## Offline architecture

`OfflineStore` is an actor-backed JSON cache in Application Support. It caches
the current athlete, active plan, and exercise library. Workout-set and
completion writes use stable UUIDs and an idempotent queue. `ConnectivityMonitor`
starts synchronization when the network becomes available. Sets sync before
session completion to preserve ordering. Authorization or validation failures
are not treated as offline writes.

The cache is a resilience layer, not an authorization source. Server RLS remains
authoritative, and cached content is never uploaded under a different user.

## Performance testing

The testing module follows the same MVVM/repository boundary as training.
`TestingRepository` owns protocol, scheduling, result, cache, and synchronization
operations. `TestingDashboardViewModel` derives coach and athlete summaries,
while `PerformanceAnalytics` is a pure, unit-tested layer for records,
improvement, averages, percentiles, season/career bests, and trend points.
Swift Charts renders trends without an additional dependency.

Testing results are cached per authenticated UUID. Offline edits are collapsed
by `(session_id, metric_id)`, so the most recent local edit wins before the
idempotent server upsert. Connectivity restoration retries pending results.

## Performance and lifecycle

- The active plan RPC removes the former week/workout/prescription N+1 pattern.
- Foreign-key and common sort/filter paths are indexed.
- ViewModels suppress duplicate loads and expose explicit loading/error states.
- Long-lived async work is cancellation-aware; network monitoring is owned by
  the repository.
- Exercise media uses URLs only; no eager image downloads occur.

## Architectural constraints

- iOS 18 or newer, SwiftUI, Swift, no non-Supabase third-party packages.
- Async/await for application I/O.
- No service-role credentials in the client.
- All schema changes are forward-only, reviewed migrations.
