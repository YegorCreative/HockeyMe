# Forge Fitness Security

## Trust boundaries

The iOS app is untrusted. It contains only the Supabase URL and publishable key.
All authorization is enforced by PostgreSQL RLS using `auth.uid()`. Service-role
credentials belong only in an approved secrets manager or ephemeral admin CLI
environment and must never be added to plist files, source, logs, or CI output.

## Authorization model

- Athletes can read/update their own profile and training assignment.
- Athletes can create sessions only for their own active assignment and a
  workout in the assigned active program.
- Athletes can create/update sets only in their own in-progress session and only
  for a matching prescribed exercise.
- Athletes cannot delete sessions/sets or write personal records.
- Coaches can access athletes only through `coach_athlete_links`.
- Coaches can manage only their programs and program descendants.
- Anonymous access to application tables and privileged functions is denied.
- Coach provisioning and coach-athlete linking are service-role only.
- Testing protocols are coach-owned; testing sessions require a linked athlete.
- Athlete-entered results require an assigned active protocol that explicitly
  enables self-entry and a metric belonging to that protocol.
- Result/session UUID relationships are validated by RLS; client-provided IDs
  cannot widen testing access.

Security-definer functions use `set search_path = ''`, schema-qualified objects,
explicit grants, and no dynamic SQL. UUIDs are decoded as UUID values, not
interpolated into SQL. Supabase query builders parameterize user input.

## Input validation

The client validates onboarding ranges, required values, workout numeric values,
publishing completeness, and duplicate assignments for usability. Database
constraints and RLS remain authoritative. Do not rely on client validation for
security.

## Audit checklist

Before each release:

1. Run linked database lint and the RLS end-to-end suite.
2. Review new functions for `security definer`, grants, and `search_path`.
3. Confirm no service-role key or user secret exists in Git history or logs.
4. Test athlete, linked coach, unrelated coach, and anonymous access.
5. Review Supabase Auth redirect URLs, email templates, and rate limits.

Report suspected key exposure by rotating the key in Supabase immediately,
revoking sessions when warranted, and auditing Auth/Postgres logs.
