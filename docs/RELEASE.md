# Forge Fitness Release

## Release channels

- Debug builds use development configuration and are never distributed.
- Staging archives use the staging Supabase project, staging bundle identifier,
  staging sender, and internal TestFlight group.
- Production archives use the production Supabase project and production App
  Store Connect application.

GitHub environments named `staging` and `production` hold distinct signing,
Supabase, and App Store Connect secrets. Production requires reviewer approval.

## Version and build numbers

The marketing version is a manual release input using semantic versioning.
GitHub `run_number` supplies the monotonically increasing
`CURRENT_PROJECT_VERSION`. Never reuse a TestFlight build number.

## Release procedure

1. Pass CI, security scanning, database replay/lint, and staging RLS tests.
2. Confirm the release notes and migration compatibility.
3. Dispatch `TestFlight Release` for staging.
4. Complete internal smoke, authentication, offline, invitation, workout, and
   testing checks.
5. Tag the approved commit.
6. Dispatch the same commit/version for production after environment approval.
7. Confirm processing, symbols, privacy answers, export compliance, and tester
   availability in App Store Connect.

## Rollback

Stop phased rollout or remove the TestFlight build from testing. Reissue the
last healthy source commit with a new build number. Database rollback uses a
forward corrective migration; never delete an applied migration. Disable
unsafe behavior with a kill-switch flag while a corrective build is reviewed.

## Required release secrets

`APPLE_TEAM_ID`, App Store Connect key ID/issuer/private key, distribution
certificate P12/password, provisioning profile, and the environment-specific
Supabase property list are required. Workflows fail before archive when any is
missing. Credentials must never be committed or printed.

## App Store privacy and capabilities

The nutrition label should declare linked, non-tracking data used for app
functionality: email address, user ID, health/fitness data, and other user
content such as training notes. Forge Fitness does not use advertising
identifiers, third-party advertising, or cross-app tracking. Validate these
answers against actual production behavior before every submission.

`PrivacyInfo.xcprivacy` declares the same categories and the UserDefaults
required-reason API. Export compliance declares no non-exempt encryption.
There are currently no custom entitlements or background modes. Do not enable
HealthKit, push notifications, background processing, associated domains, or
Keychain sharing without a reviewed product requirement, entitlement, privacy
update, and security test.
