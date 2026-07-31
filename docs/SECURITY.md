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

## Organization authorization

- Owners and administrators manage tenant membership and configuration.
- Team staff see athletes only when both are actively assigned to a team.
- Athletic trainers receive athlete access only through assigned teams.
- Parent reads require an explicit parent-to-athlete team link and never permit
  profile, workout, testing, attendance, or progress writes.
- Validation triggers reject cross-organization team and season identifiers.
- Invitation secrets are hashed, email-bound, expiring, revocable, and returned
  only once to an administrator.
- Ownership transfer is atomic and limited to the current owner.

Release verification includes owner, administrator, assigned staff, athlete,
linked parent, unrelated member, cross-organization member, and anonymous
access matrices.

## Environment isolation and invitation delivery

- Debug, Staging, and Production load different ignored configuration files.
- Debug and Staging reject URLs matching the production project reference.
- Staging scripts require explicit matching project confirmations and reject
  the production reference or a reused production service-role credential.
- Tests generate identities and never print passwords, credentials, provider
  responses, raw invitation tokens, or invitation secrets.
- Invitation creation is service-role-only. The client invokes an Edge Function
  with its user session and receives delivery status only.
- Provider credentials remain in Edge Function secrets. Rate limits apply per
  organization, requesting user, and hashed network identifier.
- Accepted, expired, revoked, and failed-delivery invitations cannot replay.

## Build, signing, and operational audit

- Signing certificates, profiles, App Store keys, Supabase configuration, and
  team ID exist only in protected CI secrets.
- Release jobs validate required variables and never echo secret values.
- Gitleaks, CodeQL, dependency review, and Dependabot cover source and supply
  chain changes.
- The app has no custom entitlements, Keychain sharing, background modes,
  advertising identifiers, HealthKit, push, or associated domains.
- Supabase owns secure session persistence; the app has no custom token store.
- Logs drop sensitive metadata names and keep accepted values private.
- Feature flags are explicitly non-secret, read-only client configuration.
