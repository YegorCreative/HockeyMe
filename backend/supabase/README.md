# Forge Fitness Supabase

This directory contains the versioned Forge Fitness database schema and canonical
exercise reference data. It must not contain passwords, access tokens, test-user
credentials, or production workout history.

## Environment boundaries

- **Production data:** real Auth users, athlete profiles, coach records,
  assignments, sessions, and workout history. Never create these through a seed
  or migration.
- **Canonical reference data:** the 18 Forge Fitness exercises. These are product
  data and are safe to deploy through the idempotent migration.
- **Development bootstrap data:** temporary accounts and training records created
  by `scripts/phase3-e2e.mjs`. The script is development-only, refuses a declared
  production project, uses generated credentials, and cleans up afterward.
- **Test data:** must use dedicated development accounts. Never reuse a personal
  or production athlete/coach account.

Keep separate Supabase projects for development and production. Record the
production project reference only in the local `FORGE_PRODUCTION_PROJECT_REF`
environment variable; do not commit environment keys.

## Coach provisioning

Migration `20260730140000_phase3_bootstrap.sql` creates:

```sql
public.provision_coach(existing_user_id uuid)
```

The function:

- requires an existing `auth.users.id`;
- inserts `public.coaches.user_id`;
- is idempotent through `ON CONFLICT DO NOTHING`;
- is revoked from `public`, `anon`, and `authenticated`;
- is executable only by `service_role`.

Never place the service-role key in the iOS app. Run provisioning only from a
trusted administrator shell or backend.

Exact administrator command:

```bash
export SUPABASE_URL='https://YOUR_DEVELOPMENT_PROJECT.supabase.co'
export SUPABASE_SERVICE_ROLE_KEY='read-from-a-secret-manager'
export COACH_USER_ID='existing-auth-user-uuid'

curl --fail-with-body --silent --show-error \
  "$SUPABASE_URL/rest/v1/rpc/provision_coach" \
  --header "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
  --header "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  --header 'Content-Type: application/json' \
  --data "{\"existing_user_id\":\"$COACH_USER_ID\"}"
```

A first call returns `true`; later calls for the same UUID return `false` and do
not create duplicates.

## Manual development bootstrap

1. Create a dedicated **athlete** user in Supabase Dashboard → Authentication →
   Users. Use the development project and mark the email confirmed.
2. Sign into the iOS app with that athlete account and complete onboarding.
   Confirm one `public.athletes` row exists with the matching Auth UUID.
3. Create a separate dedicated **coach** Auth user in the development project.
4. Copy its Auth UUID and run the administrator provisioning command above.
5. Sign in as the coach. `AppRouter` checks the secured `public.coaches` row and
   routes the account to the Coach portal.
6. Open Programs → create or edit a program → Add Exercise. The picker loads
   canonical records from `public.exercises`.

Do not add an athlete row for a coach account. Do not provision athlete accounts
as coaches unless a deliberate dual-role account is being tested.

## Canonical exercise import

The Phase 3 migration adds:

- `slug` with a unique partial index;
- `instruction_steps text[]`;
- `coach_tips_list text[]`;
- `substitutions text[]`.

The original schema already supported name, hockey category, difficulty,
equipment, primary and secondary muscles, video URL, common mistakes, active
state, and legacy text versions of instructions/tips/substitutions. The added
arrays preserve the iOS model without flattening information.

All 18 exercises use stable UUIDs and slugs. The import uses:

```sql
ON CONFLICT (slug) WHERE slug IS NOT NULL DO UPDATE
```

It is therefore safe to rerun without duplicating records. Canonical exercises
have `created_by = NULL`, making them readable under existing athlete/coach RLS
but not editable through coach-owned exercise update policies.

## Phase 3 end-to-end test

The script performs the complete coach → athlete workflow through Auth and
PostgREST, including negative RLS tests. It generates passwords in memory and
does not print them.

Required safety conditions:

- `FORGE_ENVIRONMENT` must equal `development`;
- `E2E_CONFIRM_PROJECT_REF` must match `SUPABASE_URL`;
- `FORGE_PRODUCTION_PROJECT_REF` must be set and must differ;
- `E2E_ALLOW_REMOTE_WRITES` must equal `YES_I_UNDERSTAND`.

Run:

```bash
export FORGE_ENVIRONMENT='development'
export SUPABASE_URL='https://YOUR_DEVELOPMENT_PROJECT.supabase.co'
export SUPABASE_ANON_KEY='development-anon-key'
export SUPABASE_SERVICE_ROLE_KEY='development-service-role-key'
export E2E_CONFIRM_PROJECT_REF='YOUR_DEVELOPMENT_PROJECT'
export FORGE_PRODUCTION_PROJECT_REF='YOUR_PRODUCTION_PROJECT'
export E2E_ALLOW_REMOTE_WRITES='YES_I_UNDERSTAND'

node backend/supabase/scripts/phase3-e2e.mjs
```

The script verifies:

1. coach provisioning and coach-role routing prerequisite;
2. live canonical exercise visibility;
3. program, week, workout, and prescription creation;
4. publishing and athlete assignment;
5. athlete program visibility;
6. session creation, set logging, and completion totals;
7. assigned-coach visibility;
8. unrelated-coach isolation;
9. anonymous denial.

Temporary athlete deletion cascades assignments, sessions, and sets. The script
then removes the temporary program and coach users. If a run is interrupted,
search Authentication users for the `phase3-` prefix and remove those records
from the development project only.

## Verification commands

```bash
npx --yes supabase@latest migration list --workdir backend
npx --yes supabase@latest db lint --linked --level warning --workdir backend
```

Always confirm which project is linked in `backend/supabase/.temp/project-ref`
before running a command that writes data.
