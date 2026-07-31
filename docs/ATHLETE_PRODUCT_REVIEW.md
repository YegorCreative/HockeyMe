# Forge Fitness Athlete Product Review

## Scope and method

This review covers the existing Athlete journey as of Phase 8.0:
authentication, onboarding, home, workout list, workout detail, active workout,
workout summary, exercise library, exercise detail, testing dashboard, testing
history, teams and seasons, and profile.

The review combined:

- live inspection of the Debug Developer Mode session picker and every Athlete
  destination;
- accessibility-tree inspection in the iPhone 17 Pro simulator;
- source inspection of each production SwiftUI screen and state branch;
- static review against Apple Human Interface Guidelines, Dynamic Type,
  VoiceOver, Dark Mode, reduced motion, touch-target, and performance
  expectations.

### Critical review constraint

Developer Mode currently routes every Athlete destination to the same
`DeveloperFeatureView`. It proves that roles, destinations, and production-shaped
sample records are available, but it does not render the production Athlete
screens. Therefore it cannot visually prove real loading, empty, error, Dark
Mode, Dynamic Type, animation, or navigation behavior. Correcting that should be
the next Developer Mode quality task, without changing production behavior.

## Cross-product findings

### Current strengths

- Native `NavigationStack`, `TabView`, `Form`, `ContentUnavailableView`,
  `searchable`, `refreshable`, and SF Symbols provide familiar Apple behavior.
- Most asynchronous screens distinguish loading, error, empty, and content
  states.
- Interactive controls generally have labels, hints, or combined VoiceOver
  descriptions.
- Semantic colors and Dynamic Type text styles are used instead of fixed font
  sizes.
- Lazy stacks and grids are used for the longer dashboards and collections.
- Athlete data loading remains outside view bodies and uses observable
  ViewModels.

### Current weaknesses

- **Critical:** Developer Mode does not display the production screens it claims
  to represent.
- **High:** Two-column metric layouts and horizontal control groups can compress
  badly at accessibility text sizes.
- **High:** Destructive workout completion has no confirmation step. This is
  recorded as a product concern, but is not changed in this design-only phase.
- **High:** Some empty sections use a single low-emphasis text row while other
  screens use `ContentUnavailableView`.
- **Medium:** Cards, headings, buttons, badges, and status messages were
  implemented repeatedly with small visual differences.
- **Medium:** Several screens rely on color as a primary status distinction.
- **Medium:** Charts expose a general label but not a useful audio-graph or
  point-by-point accessibility representation.
- **Low:** Most transitions are immediate; state changes lack consistent,
  reduced-motion-aware feedback.

## Screen reviews

## Authentication

### Current strengths

- Clear brand, purpose statement, and conventional email/password flow.
- Secure password entry and native text content types.
- Controls have accessible labels and logical reading order.
- Loading and friendly authentication errors are supported.

### Current weaknesses

- **High:** Configuration failure and authentication failure share the same
  visual region and may feel indistinguishable.
- **Medium:** Keyboard avoidance and the smallest supported device need visual
  regression coverage.
- **Medium:** Text links need explicit 44-point effective hit areas.
- **Low:** The logo placeholder does not yet communicate a finalized brand.

### Suggested improvements

- Separate environment/configuration status from account errors.
- Add snapshot coverage at accessibility sizes and with the software keyboard.
- Use design-system button and form patterns when behavior work resumes.

## Athlete onboarding

### Current strengths

- Short multi-step structure reduces initial form density.
- Progress is exposed visually and through VoiceOver.
- Fields use appropriate keyboard and content types.
- Back, next, validation, and saving states are clear.

### Current weaknesses

- **High:** Validation errors are presented after the fields rather than linked
  directly to the failing field.
- **High:** Bottom navigation may compete with the keyboard and larger text.
- **Medium:** Pickers and segmented shooting-side control need accessibility-size
  layout validation.
- **Medium:** The goals editor has a fixed minimum height that can dominate a
  landscape or keyboard-constrained viewport.
- **Low:** Step transitions have no consistent motion or focus movement.

### Suggested improvements

- Add field-level error descriptions and VoiceOver focus management.
- Move to a keyboard-aware safe-area action region.
- Stack horizontal actions and controls when Dynamic Type requires it.
- Use the standard motion token when step transitions are introduced.

## Athlete Home

### Current strengths

- Greeting, primary workout, recovery, streak, stats, activity, and testing form
  a logical top-to-bottom hierarchy.
- The primary workout treatment is visually distinct.
- Cards have meaningful combined accessibility labels.
- Pull-to-refresh, loading, and failure recovery are present.

### Current weaknesses

- **High:** Recovery and streak are in a fixed horizontal pair and may truncate
  at large Dynamic Type sizes.
- **High:** Mock dashboard values can appear authoritative without a clear
  placeholder state.
- **Medium:** Recent Activity and Upcoming Testing have no explicit empty
  presentation.
- **Medium:** The gradient uses white secondary text with reduced opacity; exact
  contrast should be continuously tested.
- **Low:** The inline navigation title duplicates the first screen concept
  without adding context.

### Suggested improvements

- Switch metric pairs to an adaptive grid.
- Add explicit unavailable/sample status presentation for non-live metrics.
- Use consistent empty-state components inside dashboard sections.
- Preserve the strong workout-card prominence while limiting decorative shadow.

## Workout list

### Current strengths

- Today, upcoming, and completed groupings are understandable.
- Date, duration, status icon, and navigation affordance are scannable.
- Empty active-program and retry states are provided.
- Exercise Library is available from a standard toolbar location.

### Current weaknesses

- **High:** Empty groups display “No workouts,” adding repeated visual noise.
- **Medium:** Today is distinguished by a subtle border and color; VoiceOver
  does not identify it as the emphasized/current workout.
- **Medium:** Completed workouts do not expose a textual status in the visible
  row.
- **Low:** The toolbar hockey-puck icon is domain-specific but less recognizable
  than a book/library symbol.

### Suggested improvements

- Hide empty secondary sections or use concise contextual messages.
- Include status text or a standard status badge.
- Add “today” to the accessibility label.
- Keep the new shared `WorkoutCard` as the canonical presentation.

## Workout detail

### Current strengths

- Workout purpose, duration, exercise order, sets, and reps are visible before
  starting.
- Exercise order has a clear numbered sequence.
- Empty prescriptions disable the primary action.
- Session restoration has a loading overlay and retry path.

### Current weaknesses

- **High:** Long workout descriptions and exercise names need accessibility-size
  visual testing.
- **Medium:** Coach notes, rest, tempo, and other prescription context are not
  fully surfaced in the overview.
- **Medium:** Error text and retry action are less prominent than standard error
  state treatment.
- **Low:** The title appears both in navigation and content.

### Suggested improvements

- Adopt an adaptive metadata layout and shared error component.
- Expose the most decision-relevant prescription details without increasing
  interaction complexity.
- Continue using `PrimaryButton` for the start action.

## Active workout session

### Current strengths

- Exercise and set progress are explicit.
- Previous values, RPE, pain, notes, rest, and sync status are included.
- Numeric keyboards match input.
- Buttons disable during invalid transitions and saving.
- Rest time uses monospaced digits and a VoiceOver value.

### Current weaknesses

- **Critical:** “Finish Workout” can end a session without confirmation.
- **High:** RPE and pain steppers lack explanatory context for first-time users.
- **High:** Two side-by-side numeric fields can compress at larger text sizes.
- **High:** Set indicator circles can become crowded for high-set prescriptions.
- **Medium:** Error feedback is inline and can appear outside the user’s current
  VoiceOver focus.
- **Medium:** Red tint is the main destructive-action cue.

### Suggested improvements

- Add confirmation in a future behavior-focused phase.
- Provide concise scale explanations and accessible help.
- Use adaptive field and set-progress layouts.
- Announce errors and successful set completion.
- Use semantic destructive roles in addition to color.

## Workout summary

### Current strengths

- Completion is celebratory without excessive animation.
- Volume, sets, reps, and duration form a useful summary.
- Personal records receive a distinct semantic icon.
- Done action is clear and accessible.

### Current weaknesses

- **High:** Fixed two-column metrics can truncate with large Dynamic Type.
- **Medium:** “lb” is hard-coded and not locale or athlete-unit aware.
- **Medium:** Empty personal-record copy reads as motivational content rather
  than a neutral data state.
- **Low:** Duration needs a semantic accessibility value rather than only `m:ss`.

### Suggested improvements

- Use an adaptive metric grid and locale-aware units.
- Keep `MetricCard` as the canonical summary tile.
- Provide a neutral empty state and a separate motivational message if desired.

## Exercise Library

### Current strengths

- Search, hockey-performance categories, muscle groups, and difficulty support
  efficient discovery.
- The hockey-specific header differentiates the product from a generic gym app.
- Empty, loading, error, retry, and pull-to-refresh states exist.
- Rows have useful combined accessibility labels.

### Current weaknesses

- **High:** Horizontal category filters can be difficult to discover and operate
  with large text or Switch Control.
- **Medium:** Search count can briefly imply zero data while loading.
- **Medium:** Filter pills should guarantee a 44-point target.
- **Medium:** Repeated cards have no list separators or grouping alternative,
  increasing visual density.
- **Low:** The decorative header occupies significant vertical space on smaller
  devices.

### Suggested improvements

- Provide an accessible filter menu as an alternative to horizontal pills.
- Preserve native searchable behavior and the shared empty-state component.
- Enforce minimum touch height and test Voice Control names.

## Exercise detail

### Current strengths

- Content is organized around instructions, mistakes, tips, muscles,
  substitutions, and media.
- Tags make exercise attributes scannable.
- Decorative numbered markers are hidden from VoiceOver where appropriate.

### Current weaknesses

- **High:** Long coaching content creates a lengthy, weakly navigable reading
  experience.
- **Medium:** Section headings need consistent heading traits and hierarchy.
- **Medium:** Video availability and failure states are not standardized.
- **Medium:** Tags may create awkward wraps at large text sizes.

### Suggested improvements

- Use shared section headers and cards.
- Group optional content and expose heading navigation to VoiceOver.
- Use standard media loading/error treatments when video work resumes.

## Testing dashboard

### Current strengths

- Upcoming tests, history, personal records, trends, and sync state are present.
- Charts use native Swift Charts.
- Athlete and coach capabilities are separated by role.
- Loading, error, retry, refresh, and sheets are implemented.

### Current weaknesses

- **High:** Empty Athlete performance can leave a visually sparse section with
  little guidance.
- **High:** Chart accessibility provides only a title, not values or trend
  meaning.
- **High:** Large section titles compete with the navigation title.
- **Medium:** Sync status is passive text and can be missed.
- **Medium:** Card styles are duplicated across testing views.

### Suggested improvements

- Add meaningful chart accessibility descriptors and tabular alternatives.
- Use `ChartContainer`, `TestingCard`, `StatusBadge`, and standardized section
  headers.
- Consolidate empty performance, upcoming, and history states.

## Testing history

### Current strengths

- Historical results, season best, career best, and trends are grouped by
  metric.
- Native charts provide familiar visual language.
- An empty history state exists.

### Current weaknesses

- **High:** Charts lack accessible data summaries.
- **Medium:** Dense result strings may truncate.
- **Medium:** Season and career best values rely on punctuation for separation.
- **Low:** No visible filter or time-range context is provided.

### Suggested improvements

- Add accessible chart descriptions and `StatRow` summaries.
- Use semantic grouping rather than bullet punctuation at large text sizes.
- Defer filtering functionality to a future feature phase.

## Teams and seasons

### Current strengths

- Uses native list, picker, and navigation patterns.
- Pull-to-refresh and cached organization context are supported.
- Team and season concepts are represented with production models.

### Current weaknesses

- **Critical:** Athlete navigation currently opens the organization
  administration dashboard, which can expose irrelevant create/manage controls
  depending on backend role state.
- **High:** Developer Mode does not render this screen, so role-specific visual
  restrictions cannot be verified.
- **Medium:** Current and historical season emphasis is weak.

### Suggested improvements

- Route Athlete users to the dedicated athlete team-switching/read-only
  experience in a future behavior phase.
- Add role-specific UI tests before expanding organization features.
- Use status badges for current, archived, and historical states.

## Athlete profile

### Current strengths

- Native `Form` provides familiar editing behavior and Dynamic Type support.
- Refresh, loading, empty, error, retry, saving, and success states exist.
- Text content and keyboard types are appropriate.

### Current weaknesses

- **High:** Save is a regular form row rather than a clearly persistent primary
  action.
- **Medium:** Success and error messages are plain colored text and rely on
  color.
- **Medium:** There is no non-editing summary hierarchy or avatar/identity
  context.
- **Low:** Height and weight units are hard-coded.

### Suggested improvements

- Use icon-plus-text semantic success/error treatments.
- Adopt shared form field guidance and `PrimaryButton`.
- Use `AthleteCard` or `AvatarView` for identity context when a profile visual
  refresh is authorized.

## Priority summary

### Critical

1. Make Developer Mode render actual production Athlete screens and state
   variants.
2. Confirm before destructive workout completion.
3. Correct Athlete team navigation so it cannot present management UI.

### High

1. Validate and adapt all horizontal/two-column layouts for accessibility text.
2. Add useful chart accessibility representations.
3. Improve field-linked validation and VoiceOver focus.
4. Standardize empty, loading, error, success, and sync states.
5. Add role-specific Athlete navigation and authorization UI tests.

### Medium

1. Complete adoption of shared cards, headings, badges, form, and chart
   containers.
2. Add unit and locale-aware measurements.
3. Improve non-color status cues.
4. Standardize reduced-motion-aware state transitions.

### Low

1. Refine duplicated titles and decorative vertical space.
2. Finalize brand artwork.
3. Add optional time-range presentation when analytics functionality expands.
