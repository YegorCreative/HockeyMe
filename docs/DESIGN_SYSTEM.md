# Forge Design System v1

## Purpose

Forge Design System is the permanent visual and interaction foundation for
Forge Fitness on Apple platforms. It favors native behavior, clear performance
data, restrained visual depth, and accessibility over ornamental styling.

The implementation lives in `ios/ForgeFitness/DesignSystem`.

## Design principles

1. **Performance at a glance.** Make the current action, status, and trend
   understandable before adding detail.
2. **Native by default.** Prefer SwiftUI navigation, lists, forms, tables,
   charts, menus, alerts, sheets, and platform materials.
3. **Semantic, not decorative.** Color, typography, icons, spacing, and motion
   communicate meaning.
4. **Accessible at every size.** Dynamic Type, VoiceOver, Voice Control,
   increased contrast, reduced motion, Dark Mode, and 44-point targets are
   baseline requirements.
5. **One model, appropriate presentation.** Shared model-driven components may
   adapt between compact iOS and future regular-width macOS layouts.
6. **Calm confidence.** Use depth and motion sparingly. Training data remains
   the visual focus.

## Color palette

`AppColors` defines semantic colors with separate light and Dark Mode values.
Do not introduce raw RGB values in feature views.

| Token | Purpose |
| --- | --- |
| `primary` | Primary actions, selected state, key progress |
| `primaryPressed` | Pressed and emphasized interaction state |
| `secondary` | Secondary data and supporting actions |
| `accent` | Highlights and chart differentiation |
| `background` | Standard content background |
| `groupedBackground` | Grouped lists and dashboard canvases |
| `surface` | Cards and grouped controls |
| `elevatedSurface` | Floating or inspector-level surfaces |
| `textPrimary` | Primary readable content |
| `textSecondary` | Supporting content |
| `textTertiary` | De-emphasized metadata |
| `border` / `borderStrong` | Separators and focused boundaries |
| `success` | Completed, healthy, synchronized |
| `warning` | Attention, recovery concern, pending |
| `error` | Failure, destructive, invalid |
| `info` | Informational status |
| `onAccent` | Content on strong accent backgrounds |
| `scrim` | Modal backdrop |
| `chartPalette` | Ordered accessible chart series |

Never communicate state using color alone. Pair semantic color with text, shape,
or an SF Symbol.

## Typography

All typography uses Dynamic Type.

| Token | Use |
| --- | --- |
| `largeTitle` | Rare top-level marketing or completion moments |
| `title`, `title2`, `title3` | Page and major content hierarchy |
| `headline` | Card titles, section headers, primary rows |
| `subheadline` | Secondary actions and compact metadata |
| `body` | Default readable content and forms |
| `callout` | Supporting emphasis |
| `footnote` | Dense metadata |
| `caption`, `caption2` | Labels and tertiary metadata |
| `metric`, `heroMetric` | Numeric performance values |

Do not use fixed point sizes. Avoid relying only on font weight to distinguish
hierarchy. At accessibility sizes, horizontal groups must stack or use an
adaptive grid.

## Spacing

The base scale is 2, 4, 8, 12, 16, 24, 32, 48, and 64 points:
`xxs`, `xs`, `sm`, `compact`, `md`, `lg`, `xl`, `xxl`, and `xxxl`.

Semantic aliases:

- `screenHorizontal`: standard compact-width page inset;
- `section`: separation between content groups;
- `card`: internal card padding;
- `minimumTouchTarget`: minimum interactive dimension.

Use zero only for deliberate divider or list grouping. Do not add one-off
spacing values in feature views.

## Corner radius

| Token | Use |
| --- | --- |
| `xSmall` | Dense controls and indicators |
| `small` | Fields and compact tiles |
| `medium` | Standard cards |
| `large` | Hero and workout cards |
| `xLarge` | Brand surfaces and large sheets |
| `pill` | Badges and tags |

Continuous rounded rectangles are preferred for Apple-platform cards.

## Elevation and shadows

`AppElevation` supports:

- `flat`: default cards and lists;
- `raised`: selected or emphasized cards;
- `floating`: transient overlays and inspectors.

Use elevation to explain layering, not importance. Dark Mode must retain clear
surface boundaries without heavy black shadows.

## Motion

`AppMotion` defines instant, quick, standard, and deliberate durations plus
quick, standard, and restrained spring animations.

- Quick: selection and small control feedback.
- Standard: content state and navigation-adjacent transitions.
- Deliberate: rare completion or reorganization transitions.
- Respect Reduce Motion by avoiding movement-heavy custom transitions.
- Progress and timers must not animate in a way that impairs readability.

## Component catalog

### Foundations implemented

- `ForgeCard`
- `SectionHeader`
- `PrimaryButton`
- `SecondaryButton`
- `StatusBadge`
- `AvatarView`
- `MetricCard`
- `StatRow`
- `SearchField`
- `ToolbarButton`
- `ProgressRing`
- `ChartContainer`
- `LoadingIndicator`
- `SkeletonView`
- `ForgeEmptyState`
- `ForgeErrorState`
- `ForgeSuccessState`

### Domain components implemented

- `WorkoutCard`
- `AthleteCard`
- `TestingCard`

Coach analytics should compose `MetricCard`, `ChartContainer`, and `StatRow`
rather than introduce a second visual language.

### Buttons

Use `PrimaryButton` once per decision region for the recommended action.
Use `SecondaryButton` for reversible alternatives. Use native destructive roles
for destructive actions. Icon-only toolbar actions require accessible names.

### Cards

Use `ForgeCard` for grouped dashboard content. Cards must not be nested. Prefer
native list rows when content is primarily navigational.

### Tables

Use native `Table` on regular-width platforms and a list or card transformation
on compact width. Columns must have textual headers, sorting must be announced,
and horizontal scrolling should not be required for primary data.

### Charts

Wrap visualizations in `ChartContainer`. Use `chartPalette` consistently.
Every chart requires:

- a descriptive accessibility label;
- an accessible summary of the trend;
- access to individual values or a tabular alternative;
- a clear unit and time range.

### Forms

Use native `Form`, `Section`, `TextField`, `Picker`, `DatePicker`, and
validation behavior. Errors belong next to the relevant field and must be
announced. Use appropriate content and keyboard types. Do not use placeholder
text as the only label.

### Lists

Use native `List` for navigational and management collections. Use lazy stacks
for dashboard compositions. Rows need at least a 44-point hit target and a
stable accessible name.

### Navigation

Use `NavigationStack` on iOS. Use a single tab vocabulary for Athlete journeys.
Deep destinations should preserve a meaningful back label. Do not duplicate a
navigation title as the first content heading unless it adds context.

### Sidebar, toolbar, and inspector

Future regular-width layouts should use `NavigationSplitView`, native toolbars,
and inspector presentation. `ToolbarButton` standardizes labeled actions.
Sidebar selection must remain keyboard accessible. Inspectors supplement rather
than replace primary content.

### Context menus

Use native `contextMenu` only for optional accelerators. All operations must
remain available through visible UI or keyboard commands. Use destructive
roles and confirmation where data loss is possible.

### Alerts, sheets, and dialogs

- Alerts: short blocking decisions and errors requiring acknowledgement.
- Sheets: focused creation or editing flows.
- Confirmation dialogs: destructive or mutually exclusive choices.
- Full-screen covers: immersive, interruption-sensitive tasks such as active
  workout sessions.

Actions use standard cancel, confirmation, and destructive roles.

### Badges and tags

Use `StatusBadge` for state and compact metadata. Keep labels short and pair
color with text or symbols. Do not turn every attribute into a badge.

### Loading and skeletons

Use `LoadingIndicator` for blocking first loads. Use `SkeletonView` only when
layout is stable and the load is expected to be brief. Refresh operations should
preserve existing content. Loading must have an accessible label.

### Search

Prefer native `.searchable` for primary collections. `SearchField` supports
embedded or future sidebar search. Search results must distinguish no data from
no matches.

### Empty, error, and success states

- `ForgeEmptyState`: valid absence of data, with concise guidance.
- `ForgeErrorState`: failure plus a recovery action when one exists.
- `ForgeSuccessState`: completed state that does not require interaction.

Preserve content during recoverable refresh errors instead of replacing the
entire screen.

### Calendar components

Use native `DatePicker`, calendar formatting, and locale-aware date intervals.
Testing and workout calendar cards should compose `TestingCard` or
`WorkoutCard`. Future macOS calendars should support keyboard navigation and
today/current-season emphasis without color-only meaning.

## Accessibility requirements

- Support all Dynamic Type sizes without truncating primary content.
- Use a 44-by-44-point minimum target.
- Provide logical VoiceOver order, headings, labels, values, and hints.
- Hide decorative symbols from accessibility.
- Do not rely on color, position, or animation alone.
- Honor Reduce Motion, Differentiate Without Color, Increase Contrast, and
  Reduce Transparency.
- Use locale-aware units, numbers, dates, and durations.
- Test light and Dark Mode, portrait and landscape, Voice Control, and Switch
  Control.
- Charts require an accessible data representation.

## Desktop readiness

Shared components accept model values and content closures instead of iOS-only
ViewModels. This makes them reusable by a future macOS Coach application while
allowing platform-specific containers.

Desktop adaptations should:

- replace tabs with a sidebar where appropriate;
- use tables for dense athlete and program data;
- add toolbars, keyboard shortcuts, menus, and context menus;
- use inspectors for secondary details;
- support resizable windows and multiple selection;
- keep business logic and repositories platform-neutral.

No macOS target is part of Design System v1.

## Adoption rules

1. New feature views must use semantic tokens and existing components.
2. A new component requires a repeated pattern or a distinct accessibility need.
3. Existing behavior must not be moved into visual components.
4. Platform containers remain native even when their content is shared.
5. Design-system changes require light, Dark Mode, Dynamic Type, and VoiceOver
   review plus simulator build and test verification.
