# Forge Fitness macOS Coach Architecture

## Purpose

Forge Coach is a native macOS application for professional hockey coaching
workflows. It is a separate presentation target in the existing Xcode project;
it is not an enlarged iPhone interface.

## Deployment target

The minimum deployment target is macOS 15.0. This is the newest sensible
baseline for the current project generation: it provides mature
`NavigationSplitView`, `Table`, inspector, toolbar, command, and accessibility
APIs while remaining compatible with the Xcode 27 toolchain used by the
repository. Raising the target later does not require a data migration.

## Source boundaries

Platform-specific Mac presentation lives under `ios/macOS`:

- `App` owns bootstrap and application state.
- `Navigation` owns the split-view shell.
- `Dashboard`, `Athletes`, `Programming`, `Testing`, and `Organizations` own
  section workspaces.
- `Components` owns Mac-specific Design System adapters.
- `MockData` contains Debug-only, in-memory coach fixtures.

The Mac target directly compiles the existing shared production models:

- `TrainingProgram.swift`
- `PerformanceTesting.swift`
- `Organization.swift`

It also directly compiles the shared color, typography, spacing, radius,
motion, and elevation tokens. `Colors.swift` uses semantic platform colors on
both UIKit and AppKit.

The existing concrete iOS repositories currently depend on iOS offline,
connectivity, analytics, and lifecycle services. The Mac target therefore uses
an injected `CoachAppStore` facade around the same model contracts. This avoids
copying domain models or pulling iOS lifecycle behavior into a Mac process.
A live Mac repository adapter is the next integration boundary; no database
schema change is required.

## Bootstrap and repository injection

`CoachAppBootstrap` resolves the current build environment and produces one
application store.

- Debug without `SupabaseConfig-Mac-Debug.plist` creates the Debug-only
  in-memory coach store.
- Debug with a valid non-production config enters the configured path.
- Staging requires a valid non-production Staging config.
- Production requires the production project host.
- Invalid or missing non-Debug configuration produces a safe unavailable
  state. It never falls back to sample data.

The Debug fallback does not initialize Supabase, read credentials, make
network calls, or persist sample data. `DeveloperCoachData` is enclosed in
`#if DEBUG` and is absent from Staging and Release compilation.

## Navigation and windows

The app uses one native `WindowGroup` and a balanced
`NavigationSplitView`. The primary sidebar owns eight stable destinations:
Dashboard, Athletes, Teams, Programming, Testing, Analytics, Organization, and
Settings. Sections use native tables, split views, toolbars, search, context
menus, sheets, inspectors, and confirmation dialogs.

The default window is 1,280 × 820 points with a 960 × 640 minimum. Sidebar,
content, and inspector columns are resizable. Empty selections render explicit
detail states.

## Authorization

The shell renders only when the injected session is authorized as Coach.
Staging and Release do not receive a mock Coach role. Repository and Supabase
RLS authorization remain the source of truth for live actions. The Mac UI does
not expose Parent, Athlete, or Forge Admin shells.

## Accessibility

- Native controls preserve Full Keyboard Access and system focus rings.
- Tables provide semantic column headers and selection.
- Icon-only toolbar actions include labels and help.
- Status badges expose a spoken status label.
- Semantic system colors support Light Mode, Dark Mode, Increase Contrast,
  and accessibility appearance changes.
- Reduced Motion replaces section transition animation with identity.
- Text uses semantic fonts and responds to accessibility text settings.

## Testing

`ForgeCoachTests` covers bootstrap behavior, section availability, athlete
selection, program editing, program duplication, role enforcement, and safe
aggregation of repeated metric identifiers. Existing iOS targets remain
separate and are included in regression verification.

## Known limitations

- The live authenticated Mac repository adapter is not implemented in Phase
  9.0. Configured non-Debug builds remain safely locked until it is supplied.
- Exercise picking uses an in-memory view of supported exercise choices in
  Debug. It does not invent or persist exercises.
- Ownership transfer is visible only as a guarded confirmation because the
  existing Mac repository facade does not yet expose a safe live transfer
  operation.
- Drag reordering is implemented for weeks and workouts; exercise
  prescription reordering remains dependent on the live repository adapter.
- App signing, notarization, and distribution profiles remain external release
  setup.

No database or RLS changes were made.
