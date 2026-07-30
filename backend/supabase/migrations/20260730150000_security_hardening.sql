create table public.coach_athlete_links (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null
    references public.coaches (user_id) on delete cascade,
  athlete_id uuid not null
    references public.athletes (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint coach_athlete_links_unique unique (coach_user_id, athlete_id)
);

create index coach_athlete_links_athlete_id_idx
  on public.coach_athlete_links (athlete_id);

create index if not exists workout_programs_coach_updated_at_idx
on public.workout_programs (coach_user_id, updated_at desc);

create index if not exists workouts_week_sort_order_idx
on public.workouts (program_week_id, sort_order);

create index if not exists exercises_active_name_idx
on public.exercises (name)
where is_active;

create index if not exists workout_sets_exercise_completed_at_idx
on public.workout_sets (exercise_id, completed_at desc);

alter table public.coach_athlete_links enable row level security;
revoke all on table public.coach_athlete_links from anon;
grant select on table public.coach_athlete_links to authenticated;

create policy "Coaches can view their athlete links"
on public.coach_athlete_links
for select
to authenticated
using (coach_user_id = (select auth.uid()));

create policy "Athletes can view their coach links"
on public.coach_athlete_links
for select
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
);

create or replace function public.link_coach_athlete(
  existing_coach_user_id uuid,
  existing_athlete_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.coaches
    where user_id = existing_coach_user_id
  ) then
    raise exception 'Coach does not exist';
  end if;

  if not exists (
    select 1 from public.athletes
    where id = existing_athlete_id
  ) then
    raise exception 'Athlete does not exist';
  end if;

  insert into public.coach_athlete_links (coach_user_id, athlete_id)
  values (existing_coach_user_id, existing_athlete_id)
  on conflict (coach_user_id, athlete_id) do nothing;

  return found;
end;
$$;

revoke all on function public.link_coach_athlete(uuid, uuid) from public;
revoke all on function public.link_coach_athlete(uuid, uuid) from anon;
revoke all on function public.link_coach_athlete(uuid, uuid)
  from authenticated;
grant execute on function public.link_coach_athlete(uuid, uuid)
  to service_role;

create or replace function public.coach_manages_athlete(
  check_athlete_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.coach_athlete_links link
    where link.athlete_id = check_athlete_id
      and link.coach_user_id = check_user_id
  );
$$;

create or replace function public.get_assignable_athletes()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', athlete.id,
        'first_name', athlete.first_name,
        'last_name', athlete.last_name,
        'team', athlete.team,
        'position', athlete.position,
        'graduation_year', athlete.graduation_year
      )
      order by athlete.last_name, athlete.first_name
    ),
    '[]'::jsonb
  )
  from public.coach_athlete_links link
  join public.athletes athlete on athlete.id = link.athlete_id
  where link.coach_user_id = (select auth.uid());
$$;

drop policy "Coaches can manage assignments for their programs"
on public.athlete_program_assignments;

create policy "Coaches can manage linked athlete assignments"
on public.athlete_program_assignments
for all
to authenticated
using (
  public.coach_owns_program(program_id, (select auth.uid()))
  and public.coach_manages_athlete(
    athlete_id,
    (select auth.uid())
  )
  and assigned_by = (select auth.uid())
)
with check (
  public.coach_owns_program(program_id, (select auth.uid()))
  and public.coach_manages_athlete(
    athlete_id,
    (select auth.uid())
  )
  and assigned_by = (select auth.uid())
);

create or replace function public.athlete_can_log_workout(
  check_athlete_id uuid,
  check_assignment_id uuid,
  check_workout_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.athletes athlete
    join public.athlete_program_assignments assignment
      on assignment.athlete_id = athlete.id
    join public.workout_programs program
      on program.id = assignment.program_id
    join public.workout_program_weeks week
      on week.program_id = program.id
    join public.workouts workout
      on workout.program_week_id = week.id
    where athlete.id = check_athlete_id
      and athlete.user_id = check_user_id
      and assignment.id = check_assignment_id
      and assignment.status = 'active'
      and program.status = 'active'
      and workout.id = check_workout_id
  );
$$;

revoke all on function public.athlete_can_log_workout(
  uuid, uuid, uuid, uuid
) from public;
grant execute on function public.athlete_can_log_workout(
  uuid, uuid, uuid, uuid
) to authenticated;

drop policy "Athletes can manage their workout sessions"
on public.workout_sessions;

create policy "Athletes can view their workout sessions"
on public.workout_sessions
for select
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
);

create policy "Athletes can create assigned workout sessions"
on public.workout_sessions
for insert
to authenticated
with check (
  public.athlete_can_log_workout(
    athlete_id,
    assignment_id,
    workout_id,
    (select auth.uid())
  )
);

create policy "Athletes can update their workout sessions"
on public.workout_sessions
for update
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
)
with check (
  public.athlete_can_log_workout(
    athlete_id,
    assignment_id,
    workout_id,
    (select auth.uid())
  )
);

create or replace function public.athlete_can_log_set(
  check_session_id uuid,
  check_workout_exercise_id uuid,
  check_exercise_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.workout_sessions session
    join public.athletes athlete on athlete.id = session.athlete_id
    join public.workout_exercises prescription
      on prescription.workout_id = session.workout_id
    where session.id = check_session_id
      and athlete.user_id = check_user_id
      and session.status = 'in_progress'
      and prescription.id = check_workout_exercise_id
      and prescription.exercise_id = check_exercise_id
  );
$$;

revoke all on function public.athlete_can_log_set(
  uuid, uuid, uuid, uuid
) from public;
grant execute on function public.athlete_can_log_set(
  uuid, uuid, uuid, uuid
) to authenticated;

drop policy "Athletes can manage their workout sets"
on public.workout_sets;

create policy "Athletes can view their workout sets"
on public.workout_sets
for select
to authenticated
using (
  exists (
    select 1
    from public.workout_sessions session
    where session.id = session_id
      and public.athlete_owns_profile(
        session.athlete_id,
        (select auth.uid())
      )
  )
);

create policy "Athletes can create valid workout sets"
on public.workout_sets
for insert
to authenticated
with check (
  public.athlete_can_log_set(
    session_id,
    workout_exercise_id,
    exercise_id,
    (select auth.uid())
  )
);

create policy "Athletes can update valid workout sets"
on public.workout_sets
for update
to authenticated
using (
  exists (
    select 1
    from public.workout_sessions session
    where session.id = session_id
      and public.athlete_owns_profile(
        session.athlete_id,
        (select auth.uid())
      )
  )
)
with check (
  public.athlete_can_log_set(
    session_id,
    workout_exercise_id,
    exercise_id,
    (select auth.uid())
  )
);

drop policy "Athletes can manage their personal records"
on public.personal_records;

create policy "Athletes can view their personal records"
on public.personal_records
for select
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
);

create or replace function public.get_active_training_plan()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'assignment_id', assignment.id,
    'starts_on', assignment.starts_on,
    'weeks', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', week.id,
            'week_number', week.week_number,
            'workouts', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', workout.id,
                    'name', workout.name,
                    'description', workout.description,
                    'day_number', workout.day_number,
                    'estimated_duration_minutes',
                      workout.estimated_duration_minutes,
                    'sort_order', workout.sort_order,
                    'completed', exists (
                      select 1
                      from public.workout_sessions session
                      where session.athlete_id = athlete.id
                        and session.workout_id = workout.id
                        and session.status = 'completed'
                    ),
                    'exercises', coalesce(
                      (
                        select jsonb_agg(
                          jsonb_build_object(
                            'id', prescription.id,
                            'exercise_id', exercise.id,
                            'name', exercise.name,
                            'description', exercise.description,
                            'category', exercise.category,
                            'difficulty', exercise.difficulty,
                            'sets', prescription.sets,
                            'reps_min', prescription.reps_min,
                            'reps_max', prescription.reps_max,
                            'rest_seconds', prescription.rest_seconds,
                            'coach_notes', prescription.coach_notes,
                            'sort_order', prescription.sort_order
                          )
                          order by prescription.sort_order
                        )
                        from public.workout_exercises prescription
                        join public.exercises exercise
                          on exercise.id = prescription.exercise_id
                        where prescription.workout_id = workout.id
                      ),
                      '[]'::jsonb
                    )
                  )
                  order by workout.sort_order, workout.day_number
                )
                from public.workouts workout
                where workout.program_week_id = week.id
              ),
              '[]'::jsonb
            )
          )
          order by week.week_number
        )
        from public.workout_program_weeks week
        where week.program_id = program.id
      ),
      '[]'::jsonb
    )
  )
  from public.athlete_program_assignments assignment
  join public.athletes athlete
    on athlete.id = assignment.athlete_id
  join public.workout_programs program
    on program.id = assignment.program_id
  where athlete.user_id = (select auth.uid())
    and assignment.status = 'active'
    and program.status = 'active'
  order by assignment.starts_on desc
  limit 1;
$$;

revoke all on function public.get_active_training_plan() from public;
revoke all on function public.get_active_training_plan() from anon;
grant execute on function public.get_active_training_plan()
  to authenticated;
