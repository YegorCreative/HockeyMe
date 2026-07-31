# Forge Fitness Runbook

## Authentication outage

1. Confirm Supabase status and environment configuration.
2. Review privacy-safe authentication error codes and network diagnostics.
3. Check Auth rate limits, email confirmation, redirect URLs, and provider
   configuration.
4. Disable affected entry points with an existing kill switch if necessary.
5. Do not log credentials, tokens, email addresses, or request bodies.

## Database or RLS regression

1. Halt deployments and writes affected by the policy.
2. Reproduce with the staging REST/RPC matrix.
3. Inspect the latest migration and Postgres logs.
4. Create a forward-only corrective migration.
5. Run empty-database replay, lint, cross-tenant tests, and backup verification.

## Invitation delivery failure

1. Check Edge Function health and Resend status without exposing tokens.
2. Confirm sender verification and staging/production secret separation.
3. Review aggregate delivery failure codes and rate-limit counters.
4. Failed sends are revoked automatically; retry by creating a new invitation.

## Offline synchronization backlog

1. Check network status, Supabase API health, and authorization errors.
2. Confirm queued writes remain isolated by authenticated user UUID.
3. Never delete the queue to mask a server error.
4. Verify idempotent set/result upserts and conflict resolution in staging.

## TestFlight processing failure

Check signing, provisioning, export compliance, privacy manifest, build number,
App Store Connect API status, and uploaded symbols. Rebuild from the same commit
with a new build number after correction.
