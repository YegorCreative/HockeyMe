alter table public.workout_sessions
  add column total_sets integer,
  add column total_reps integer,
  add column total_volume numeric(14, 2);

alter table public.workout_sessions
  add constraint workout_sessions_total_sets_nonnegative
    check (total_sets is null or total_sets >= 0),
  add constraint workout_sessions_total_reps_nonnegative
    check (total_reps is null or total_reps >= 0),
  add constraint workout_sessions_total_volume_nonnegative
    check (total_volume is null or total_volume >= 0);

create unique index workout_sessions_one_active_per_workout_idx
on public.workout_sessions (athlete_id, workout_id)
where status = 'in_progress' and workout_id is not null;

alter table public.workout_sets
  drop constraint workout_sets_session_number_unique;

alter table public.workout_sets
  add constraint workout_sets_prescription_number_unique unique (
    session_id,
    workout_exercise_id,
    set_number
  );
