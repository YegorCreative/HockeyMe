# Forge Fitness Architecture

## System overview

Forge Fitness is a native SwiftUI iOS client backed by Supabase Auth and
PostgreSQL. The iOS app follows MVVM:

- `Views` render state and dispatch user actions.
- `ViewModels` own presentation state and structured-concurrency tasks.
- `Backend` services and repositories are the only database boundary.
- `Models` are transport-independent domain values.
- `AppRouter` restores authentication and selects athlete or coach navigation.

Environment-specific publishable configuration is supplied through ignored
Debug, Staging, or Production property lists. Compile-time environment
selection must match the file, and non-production builds reject the production
project reference. PostgreSQL RLS remains the authorization boundary.
Service-role credentials exist only in server and administrator secret stores.

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

## Organizations and teams

`OrganizationRepository` is the async boundary for organization, membership,
team, season, invitation, analytics, and parent-read operations.
`OrganizationViewModel` owns selection and presentation state. Context is
cached by authenticated user UUID; cached membership never grants access
because every live operation is re-authorized by Supabase RLS.

Routing derives the experience from active organization roles. Staff receive
coach navigation, athletes retain athlete navigation, and parent-only members
receive a read-only experience. Memberships support multiple roles,
organizations, teams, and historical seasons.

## Invitation delivery

The iOS repository invokes `send-organization-invitation` and never receives a
raw token. The Edge Function verifies the Auth user, calls a service-role-only
workflow, applies organization/user/network rate limits, and sends HTML plus
plain text through Resend. Only a SHA-256 token hash is persisted. Delivery
failure revokes the invitation; acceptance is email-bound and single-use.

## Release infrastructure and observability

GitHub Actions separates iOS build/test/UI test, SwiftLint, migration replay,
database lint, documentation, CodeQL, dependency review, secret scanning, and
TestFlight release responsibilities. Releases use protected environments.

Native observability uses unified logging, MetricKit, duration metrics, and
privacy-safe network status classes. Sensitive metadata keys are dropped and
remaining values are private. Analytics is operational, optional, and does not
use advertising identifiers or cross-app tracking.

`FeatureFlagService` reads non-secret Supabase configuration, caches by
environment, and evaluates kill switches, versions, internal/beta audiences,
and deterministic authenticated-user rollout buckets.
