# Forge Fitness Operations

## Ownership

The release owner coordinates iOS, Supabase, Auth, email, and App Store
operations. A second reviewer approves production deployments and credential
rotation. Every production change must identify an operator, commit, migration
set, expected impact, verification evidence, and rollback owner.

## Routine checks

- Review CI/security results and dependency advisories weekly.
- Review MetricKit crash, hang, launch, memory, and disk reports after releases.
- Review Supabase database/Auth/API logs, slow queries, backups, and capacity.
- Review invitation provider delivery, bounce, complaint, and rate-limit data.
- Verify staging restore and RLS matrices before each production release.
- Test backup restoration quarterly in an isolated project.

## Access management

Use least-privilege GitHub, Apple Developer, App Store Connect, Supabase, and
email-provider roles. Service-role credentials belong only in protected server
environments. Remove departing operators promptly and review access quarterly.

## Feature flags

Flags contain no secrets or personal data. Production changes require review.
Kill switches use `enabled=false`. Rollouts are deterministic per authenticated
user, environment-scoped, and may target all, beta, or internal audiences.
Record the reason, owner, start time, percentage, monitoring signal, and removal
date for each rollout.
