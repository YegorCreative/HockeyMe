# Forge Fitness Testing Guide

## Principles

- Tests must never target Production.
- Database tests require explicit staging confirmation.
- Fixtures use dedicated identities and are cleaned up.
- Unexpected access fails loudly.
- Compiler warnings fail builds.
- Secrets, passwords, tokens, and invitation codes never appear in output.

## iOS build

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project ios/ForgeFitness.xcodeproj \
  -scheme "Forge Fitness" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  CODE_SIGNING_ALLOWED=NO build
```

Repeat with `-configuration Release` and a generic iOS Simulator destination.

## iOS tests

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project ios/ForgeFitness.xcodeproj \
  -scheme "Forge Fitness" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  CODE_SIGNING_ALLOWED=NO test
```

Critical coverage includes environment safety, authentication presentation,
offline cache isolation, workout queue idempotency, testing analytics,
organization roles, Developer Mode repositories, and accessible authentication
controls.

## macOS build and tests

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project ios/ForgeFitness.xcodeproj \
  -scheme "Forge Coach" \
  -configuration Debug \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO test
```

Repeat the build with Release configuration. Mac tests cover config-free
Developer Mode, role boundaries, navigation, athlete selection, programming
validation and duplication, assignments, environment host safety, and testing
metric aggregation.

## SwiftLint

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
swiftlint lint --strict --no-cache
```

The configured scope includes iOS, macOS, and both test targets.

## Backend verification

From an explicitly confirmed staging environment:

1. Start an empty local or dedicated staging database.
2. Replay every migration in timestamp order.
3. Run Supabase database lint.
4. Verify RLS is enabled on every application table.
5. Verify the 18 canonical exercises.
6. Run anonymous-denial tests.
7. Run the authenticated two-organization matrix.
8. Run expired, revoked, duplicate, and replayed invitation tests.
9. Clean up fixtures.

Never bypass the production guards in `backend/supabase/scripts`.

## Manual accessibility matrix

Test every primary workflow with:

- VoiceOver;
- Full Keyboard Access on Mac;
- largest accessibility text size on iPhone;
- Increase Contrast;
- Differentiate Without Color;
- Reduce Motion;
- Light and Dark appearances;
- empty, loading, error, stale, and retry states.

Confirm meaningful labels, logical focus order, non-color status communication,
and keyboard reachability.

## Performance baselines

Use release-like staging data. Record:

- cold and warm launch;
- first athlete/program/testing load;
- search latency for 500 athletes;
- scrolling hitch rate;
- program detail query count;
- memory after repeated navigation;
- workout queue synchronization duration;
- testing history decoding and chart preparation.

Record hardware, OS, build SHA, fixture size, and Instruments template. Optimize
only regressions or budget violations.
