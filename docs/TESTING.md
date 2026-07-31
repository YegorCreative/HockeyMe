# Forge Fitness Testing

## Test layers

- `ForgeFitnessTests`: deterministic unit tests for cache serialization,
  idempotent offline queues, performance analytics, supported metric coverage,
  user cache isolation, domain values, and business-facing errors.
- `ForgeFitnessUITests`: smoke coverage for the accessible authentication
  surface. The `-ui-testing` launch argument uses the logged-out route and never
  changes production behavior.
- `backend/supabase/scripts/phase3-e2e.mjs`: integration coverage for Auth,
  onboarding, coach routing, exercises, program creation/publishing/assignment,
  workout loading/session/set/completion, linked-coach reads, unrelated-coach
  denial, and anonymous denial.
- Supabase database lint: SQL and policy static validation.

## Commands

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild test -project ios/ForgeFitness.xcodeproj \
  -scheme ForgeFitness -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

npx --yes supabase@latest db lint --linked --workdir backend --level warning
node backend/supabase/scripts/phase3-e2e.mjs
```

The database test requires explicitly configured development credentials; it
refuses non-development project references and never prints passwords or keys.
Do not point it at production.

## Release gate

All unit/UI tests, the isolated backend integration workflow, linked database
lint, and a Debug simulator build must pass with zero warnings. A skipped
environment-dependent test is not a pass; record it as unverified.

Performance testing release checks cover higher/lower-is-better improvement,
season/career bests, percentile direction, chronological trend data, the
standard hockey metric catalog, and offline metric conflict collapse.

Phase 6 adds organization multi-role classification and per-user offline
context isolation tests. The read-only
`backend/supabase/scripts/phase6-anonymous-rls.mjs` check verifies all seven
organization tables reveal no anonymous rows and organization creation fails.

Authenticated integration coverage must use isolated development accounts for
two organizations and exercise owner/admin, assigned coach, trainer, athlete,
linked parent, unrelated coach, and cross-tenant denial. Never create those
fixtures automatically in production.

## Phase 6.1 staging matrix

`phase6-staging-rls.mjs` creates eleven generated staging identities across two
organizations, exercises direct REST/RPC authorization, prints a PASS/FAIL
matrix, and removes organizations and Auth users in `finally`. It covers tenant
isolation, unassigned/anonymous denial, staff and parent scope, ownership,
movement, cloning, archiving, soft deletion, invitation duplicate/expiry/
revocation/replay, canonical exercise count, and optional email delivery.

```bash
set -a
source backend/supabase/.env.staging
set +a
node backend/supabase/scripts/guard-staging.mjs
node backend/supabase/scripts/phase6-anonymous-rls.mjs
node backend/supabase/scripts/phase6-staging-rls.mjs
```

Replay migrations against a newly created empty staging project before running
the matrix. A skipped environment-dependent matrix is not a pass.

## Continuous integration

CI builds with application-target warnings-as-errors, runs unit/UI tests,
uploads xcresults, runs strict SwiftLint, replays Supabase migrations, runs
database lint, type-checks Edge Functions, verifies migration/RLS/exercises,
and validates Markdown. Security CI runs Gitleaks, CodeQL, and pull-request
dependency review.

Feature-flag tests cover environment and audience targeting plus kill switches.
Analytics tests confirm user opt-out.
