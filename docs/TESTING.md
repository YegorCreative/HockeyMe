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
