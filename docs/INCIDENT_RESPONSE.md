# Forge Fitness Incident Response

## Response process

1. Detect and assign severity.
2. Name an incident commander, operations lead, communications lead, and
   recorder.
3. Contain impact: halt rollout, revoke credentials, activate an existing kill
   switch, or disable a provider integration.
4. Preserve privacy-safe logs, migration history, build IDs, and timestamps.
5. Eradicate the cause and recover through reviewed changes.
6. Validate tenant isolation, data integrity, backups, and client health.
7. Communicate status without disclosing athlete or credential information.
8. Complete a blameless post-incident review and track corrective actions.

## Security incidents

For suspected credential exposure, rotate the credential at its provider,
revoke affected sessions, examine audit logs, and search repository history.
For suspected cross-organization access, stop affected APIs, preserve evidence,
validate the RLS matrix, and follow applicable notification requirements.

## Recovery criteria

Recovery requires passing CI, relevant integration/RLS tests, service health,
data-integrity checks, and monitored canary rollout. The incident commander
records the final build, migration, restored backup point when applicable, and
evidence supporting closure.

## Post-incident review

Document timeline, impact, detection gap, root cause, contributing factors,
response effectiveness, recovery, and prioritized prevention work. Never put
tokens, passwords, private keys, raw invitation codes, or personal athlete data
in the review.
