# Forge Coach Product Guide

## Dashboard

Dashboard summarizes only information derived from current repository models:
organization, active teams, athlete count, published programs, configured
program workouts, completed testing sessions, and assigned athletes. Quick
actions navigate to supported workflows.

## Athletes

Athletes uses a dense three-column workflow:

1. Team, season, and position filters.
2. A searchable, sortable, multi-select native table.
3. A coach-visible profile inspector.

The inspector shows the existing profile summary, current program assignment,
training state, and testing summary. Phase 9.0 does not add athlete editing.

## Teams

Teams provides a searchable native table with age group, archive status, and a
derived athlete count. Archive is available from the context menu.

## Programming

Programming provides program navigation, week/workout hierarchy, and a workout
inspector. Coaches can create, duplicate, publish/unpublish, and archive
programs; add and reorder weeks and workouts; edit workout metadata; add
existing exercise choices; and assign the selected program from the athlete
table context menu.

Publishing remains disabled until at least one workout exists. Archive uses a
destructive confirmation dialog.

## Testing and analytics

Testing provides protocol navigation, session review, search, tables, and a
result inspector. Duplicate metric identifiers are grouped before display and
the newest result wins, preserving the Phase 8.1 aggregation safety behavior.
Analytics shows repository-derived result, assignment, and protocol counts. It
does not produce medical or readiness interpretations.

## Organization

Organization exposes existing members, roles, seasons, and invitations through
native tables. Invitation revocation uses a context menu in Developer Mode.
Ownership transfer is guarded and intentionally does not mutate data until a
live authorized repository operation is available.

## Developer Mode

In a Debug build with no Mac Debug Supabase configuration, Forge Coach launches
as a Coach using production-shaped, in-memory sample data. A COACH and
DEVELOPER indicator appears in the sidebar. Data resets when the process exits.
There is no authentication, Supabase initialization, networking, credential
loading, or persistence in this mode.

Developer Mode never exists in Staging or Release.

## Remaining placeholders and limitations

There are no placeholder section screens. Some mutation endpoints remain
intentionally guarded until the live Mac repository adapter exists:

- ownership transfer;
- live member-role updates;
- signed-in Staging and Production data loading;
- live exercise-library search;
- durable unsaved-change recovery.

These are integration limitations, not new product features. The underlying
schema was not changed.
