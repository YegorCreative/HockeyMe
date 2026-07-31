# Forge Fitness Deployment

## Environments

Use separate Supabase projects for development, test/staging, and production.
Keep each project's URL, publishable key, database password, and service-role
key in the environment's secret store. Development bootstrap and E2E records
must never be inserted into production.

The iOS project has Debug, Staging, and Release configurations. They use
ignored `SupabaseConfig-Debug.plist`, `SupabaseConfig-Staging.plist`, and
`SupabaseConfig-Production.plist` files respectively. Staging has a distinct
bundle ID/display name and a visible STAGING badge. Copy the matching example,
inject secrets in CI, and run `validate-environment.mjs` before archiving.

## Database deployment

1. Create a managed Supabase backup or point-in-time recovery checkpoint.
2. Run database lint and review `db push --dry-run` against staging.
3. Apply migrations to staging and run the complete E2E workflow.
4. Apply the identical committed migrations to production.
5. Verify migration history, table/RPC grants, RLS, Auth, and representative
   read/write paths.

Migrations should be additive and backward-compatible with the currently
released app. Deploy database compatibility before an app version that consumes
it.

## iOS deployment

Build Release with `SupabaseConfig-Production.plist`, archive in Xcode, run
the test plan, validate the archive, then distribute through TestFlight before
App Store release. Confirm the archive contains no service-role credentials or
development configuration.

## Rollback

Prefer a forward corrective migration. If an app release fails, halt rollout
and select the previous App Store build while keeping schema compatibility.
For a destructive migration incident, stop writes, restore the pre-deployment
backup into a new project/database, validate row counts and RLS, rotate
credentials if needed, then switch traffic using the documented incident plan.
Never edit an already-applied migration.

## Backup and recovery

- Enable Supabase daily backups and point-in-time recovery appropriate to the
  production plan.
- Quarterly, restore a backup into an isolated project and run integrity/RLS
  checks plus the E2E workflow.
- Record recovery point objective, recovery time objective, backup timestamps,
  restoration owner, and validation results.
- Export Auth/configuration settings separately; database backups alone do not
  capture every dashboard setting.

For the organization release, apply `20260730190000_organizations.sql` followed
by `20260730200000_organization_workflows.sql`. Before production, configure an
approved invitation email provider to carry the one-time code, and run the
two-organization RLS matrix in staging.

## Staging creation and replay

Create a separate Supabase project with its own password, project reference,
database, Auth users, Storage, service role, and verified staging email sender.
Do not clone production. After `guard-staging.mjs` passes:

```bash
npx --yes supabase@latest link \
  --project-ref "$FORGE_STAGING_PROJECT_REF" --workdir backend
npx --yes supabase@latest db push --workdir backend
npx --yes supabase@latest db lint --linked --level warning --workdir backend
npx --yes supabase@latest functions deploy \
  send-organization-invitation --workdir backend
```

Set staging Edge secrets for `RESEND_API_KEY`, `INVITATION_FROM_EMAIL`,
`INVITATION_ACCEPT_URL`, `APP_ENVIRONMENT=staging`, and
`FORGE_PRODUCTION_PROJECT_REF`. Production uses a different sender and secrets.
Never run reset/fixture commands before the staging guard passes.

## TestFlight automation

`TestFlight Release` accepts staging/production and semantic-version inputs,
uses GitHub `run_number` as the build number, validates secrets, installs
ephemeral signing assets, injects ignored configuration, archives, exports,
uploads, and retains the IPA artifact. Production must use required reviewers.

See `RELEASE.md`, `OPERATIONS.md`, `RUNBOOK.md`, `MONITORING.md`, and
`INCIDENT_RESPONSE.md` for release and recovery operations.
