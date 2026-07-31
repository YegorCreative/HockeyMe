# Forge Fitness Database

## Core identity

- `auth.users` is managed by Supabase Auth.
- `athletes.user_id` is unique and owns one athlete profile.
- `coaches.user_id` is unique and is provisioned only by the service-role admin
  workflow.
- `coach_athlete_links` establishes the explicit coaching relationship used by
  coach read and assignment policies.

## Training model

`workout_programs` → `workout_program_weeks` → `workouts` →
`workout_exercises` → `exercises`.

`athlete_program_assignments` connects a linked athlete to a coach-owned
published program. `workout_sessions` records one athlete workout attempt;
`workout_sets` stores prescribed-exercise set results. `personal_records`
contains derived records and is athlete-readable but not client-writable.

## Performance testing model

`testing_protocols` contains coach-owned, versioned protocol definitions with
draft, active, inactive, and archived lifecycle states.
`testing_metrics` contains ordered standard or custom numeric metrics, their
units, category, instructions, and higher/lower-is-better direction.
`testing_sessions` schedules one protocol for one linked athlete and stores a
season label. `testing_results` stores one result per session/metric while
retaining earlier sessions for longitudinal history and season comparisons.

Coaches can manage testing records only for explicitly linked athletes. Athletes
can read only their sessions/results and submit results only when the active
protocol enables athlete entry.

Foreign keys use cascade behavior for true aggregate children. Frequently
queried foreign keys, ownership columns, ordering columns, active exercises,
and exercise-history timestamps are indexed. Every mutable application table
has `created_at`, `updated_at`, and an `updated_at` trigger where applicable.

## Database API

- `get_active_training_plan()` returns the authenticated athlete's current plan
  as nested JSON, avoiding client N+1 queries.
- `get_assignable_athletes()` returns only athletes explicitly linked to the
  authenticated coach.
- `provision_coach(uuid)` and `link_coach_athlete(uuid, uuid)` are service-role
  only.

## Migration policy

Migrations live in `backend/supabase/migrations` and are immutable after
production release. Validate with:

```sh
npx --yes supabase@latest db lint --linked --workdir backend --level warning
npx --yes supabase@latest db push --dry-run --workdir backend
```

Apply to development, test, staging, then production. Never use seed or
end-to-end scripts against production. See `DEPLOYMENT.md` for rollback and
recovery.

## Organization model

- `organizations` owns the tenant boundary and current owner.
- `organization_members` links Auth users with validated multi-role arrays.
- `teams` supports archive and soft deletion.
- `team_members` assigns staff, athletes, and parent links.
- `seasons` and `season_assignments` retain historical team placement.
- `invitations` stores only token hashes and supports roles, teams, expiration,
  acceptance/decline, revocation, and duplicate prevention.

Scoped relationship tables repeat `organization_id`; validation triggers reject
cross-organization UUID combinations. Atomic workflows use
`create_organization`, `transfer_organization_ownership`,
the service-only invitation delivery workflow,
`respond_to_organization_invitation`, and `clone_team_to_season`.

Phase 6.1 adds `invitation_delivery_attempts`, an RLS-inaccessible rate-limit
ledger containing only email/network hashes. Invitation rows record delivery
state without provider credentials or raw tokens. Service-role-only delivery
functions create and finalize invitations; authenticated users may accept,
decline, or revoke only through scoped RPCs. `move_athlete_to_team` atomically
updates active team membership and season assignment, while the hardened
ownership transfer preserves a valid role for the outgoing owner.
