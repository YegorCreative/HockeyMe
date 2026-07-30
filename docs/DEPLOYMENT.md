# Forge Fitness Deployment

## Environments

Use separate Supabase projects for development, test/staging, and production.
Keep each project's URL, publishable key, database password, and service-role
key in the environment's secret store. Development bootstrap and E2E records
must never be inserted into production.

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

Build Release with the production `SupabaseConfig.plist`, archive in Xcode, run
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
