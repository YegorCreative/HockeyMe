create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.coaches (user_id) on delete set null,
  name text not null,
  description text,
  category text not null,
  hockey_category text,
  primary_muscles text[] not null default '{}',
  secondary_muscles text[] not null default '{}',
  equipment text[] not null default '{}',
  difficulty text,
  video_url text,
  instructions text,
  common_mistakes text[] not null default '{}',
  coach_tips text,
  substitution_notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercises_name_not_blank check (btrim(name) <> '')
);

create table public.workout_programs (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null references public.coaches (user_id) on delete restrict,
  name text not null,
  description text,
  status text not null default 'draft',
  duration_weeks integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_programs_name_not_blank check (btrim(name) <> ''),
  constraint workout_programs_duration_positive check (duration_weeks > 0),
  constraint workout_programs_status_valid check (
    status in ('draft', 'active', 'archived')
  )
);

create table public.workout_program_weeks (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.workout_programs (id) on delete cascade,
  week_number integer not null,
  name text,
  focus text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_program_weeks_number_positive check (week_number > 0),
  constraint workout_program_weeks_program_number_unique unique (
    program_id,
    week_number
  )
);

create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  program_week_id uuid not null references public.workout_program_weeks (id) on delete cascade,
  name text not null,
  description text,
  day_number integer not null,
  estimated_duration_minutes integer,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workouts_name_not_blank check (btrim(name) <> ''),
  constraint workouts_day_positive check (day_number > 0),
  constraint workouts_duration_positive check (
    estimated_duration_minutes is null
    or estimated_duration_minutes > 0
  ),
  constraint workouts_week_day_unique unique (
    program_week_id,
    day_number,
    sort_order
  )
);

create table public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.workouts (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete restrict,
  sort_order integer not null,
  sets integer not null,
  reps_min integer,
  reps_max integer,
  duration_seconds integer,
  rest_seconds integer not null default 0,
  target_rpe numeric(3, 1),
  coach_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_exercises_sets_positive check (sets > 0),
  constraint workout_exercises_reps_min_positive check (
    reps_min is null or reps_min > 0
  ),
  constraint workout_exercises_reps_max_valid check (
    reps_max is null
    or (reps_max > 0 and (reps_min is null or reps_max >= reps_min))
  ),
  constraint workout_exercises_duration_positive check (
    duration_seconds is null or duration_seconds > 0
  ),
  constraint workout_exercises_rest_nonnegative check (rest_seconds >= 0),
  constraint workout_exercises_rpe_valid check (
    target_rpe is null or target_rpe between 1 and 10
  ),
  constraint workout_exercises_workout_order_unique unique (
    workout_id,
    sort_order
  )
);

create table public.athlete_program_assignments (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  program_id uuid not null references public.workout_programs (id) on delete cascade,
  assigned_by uuid not null references public.coaches (user_id) on delete restrict,
  starts_on date not null,
  ends_on date,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint athlete_program_assignments_dates_valid check (
    ends_on is null or ends_on >= starts_on
  ),
  constraint athlete_program_assignments_status_valid check (
    status in ('scheduled', 'active', 'completed', 'cancelled')
  )
);

create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  assignment_id uuid references public.athlete_program_assignments (id) on delete set null,
  workout_id uuid references public.workouts (id) on delete set null,
  status text not null default 'in_progress',
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_seconds integer,
  session_rpe numeric(3, 1),
  athlete_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_sessions_status_valid check (
    status in ('in_progress', 'completed', 'abandoned')
  ),
  constraint workout_sessions_dates_valid check (
    completed_at is null or completed_at >= started_at
  ),
  constraint workout_sessions_duration_nonnegative check (
    duration_seconds is null or duration_seconds >= 0
  ),
  constraint workout_sessions_rpe_valid check (
    session_rpe is null or session_rpe between 1 and 10
  )
);

create table public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  workout_exercise_id uuid references public.workout_exercises (id) on delete set null,
  exercise_id uuid not null references public.exercises (id) on delete restrict,
  set_number integer not null,
  weight numeric(10, 2),
  reps integer,
  duration_seconds integer,
  distance numeric(10, 2),
  distance_unit text,
  rpe numeric(3, 1),
  pain_level integer,
  notes text,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workout_sets_number_positive check (set_number > 0),
  constraint workout_sets_weight_nonnegative check (
    weight is null or weight >= 0
  ),
  constraint workout_sets_reps_nonnegative check (reps is null or reps >= 0),
  constraint workout_sets_duration_nonnegative check (
    duration_seconds is null or duration_seconds >= 0
  ),
  constraint workout_sets_distance_nonnegative check (
    distance is null or distance >= 0
  ),
  constraint workout_sets_rpe_valid check (
    rpe is null or rpe between 1 and 10
  ),
  constraint workout_sets_pain_valid check (
    pain_level is null or pain_level between 1 and 10
  ),
  constraint workout_sets_session_number_unique unique (
    session_id,
    exercise_id,
    set_number
  )
);

create table public.personal_records (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  workout_session_id uuid references public.workout_sessions (id) on delete set null,
  record_type text not null,
  value numeric(12, 3) not null,
  unit text not null,
  achieved_at timestamptz not null default now(),
  is_current boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint personal_records_type_not_blank check (btrim(record_type) <> ''),
  constraint personal_records_unit_not_blank check (btrim(unit) <> '')
);

create index exercises_created_by_idx on public.exercises (created_by);
create index workout_programs_coach_user_id_idx
  on public.workout_programs (coach_user_id);
create index workout_program_weeks_program_id_idx
  on public.workout_program_weeks (program_id);
create index workouts_program_week_id_idx
  on public.workouts (program_week_id);
create index workout_exercises_workout_id_idx
  on public.workout_exercises (workout_id);
create index workout_exercises_exercise_id_idx
  on public.workout_exercises (exercise_id);
create index athlete_program_assignments_athlete_id_idx
  on public.athlete_program_assignments (athlete_id);
create index athlete_program_assignments_program_id_idx
  on public.athlete_program_assignments (program_id);
create index athlete_program_assignments_assigned_by_idx
  on public.athlete_program_assignments (assigned_by);
create index athlete_program_assignments_active_idx
  on public.athlete_program_assignments (athlete_id, status, starts_on);
create index workout_sessions_athlete_id_idx
  on public.workout_sessions (athlete_id);
create index workout_sessions_assignment_id_idx
  on public.workout_sessions (assignment_id);
create index workout_sessions_workout_id_idx
  on public.workout_sessions (workout_id);
create index workout_sessions_athlete_started_at_idx
  on public.workout_sessions (athlete_id, started_at desc);
create index workout_sets_session_id_idx
  on public.workout_sets (session_id);
create index workout_sets_workout_exercise_id_idx
  on public.workout_sets (workout_exercise_id);
create index workout_sets_exercise_id_idx
  on public.workout_sets (exercise_id);
create index personal_records_athlete_id_idx
  on public.personal_records (athlete_id);
create index personal_records_exercise_id_idx
  on public.personal_records (exercise_id);
create index personal_records_workout_session_id_idx
  on public.personal_records (workout_session_id);
create index personal_records_current_idx
  on public.personal_records (athlete_id, exercise_id, record_type)
  where is_current;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger exercises_set_updated_at
before update on public.exercises
for each row execute function public.set_updated_at();
create trigger workout_programs_set_updated_at
before update on public.workout_programs
for each row execute function public.set_updated_at();
create trigger workout_program_weeks_set_updated_at
before update on public.workout_program_weeks
for each row execute function public.set_updated_at();
create trigger workouts_set_updated_at
before update on public.workouts
for each row execute function public.set_updated_at();
create trigger workout_exercises_set_updated_at
before update on public.workout_exercises
for each row execute function public.set_updated_at();
create trigger athlete_program_assignments_set_updated_at
before update on public.athlete_program_assignments
for each row execute function public.set_updated_at();
create trigger workout_sessions_set_updated_at
before update on public.workout_sessions
for each row execute function public.set_updated_at();
create trigger workout_sets_set_updated_at
before update on public.workout_sets
for each row execute function public.set_updated_at();
create trigger personal_records_set_updated_at
before update on public.personal_records
for each row execute function public.set_updated_at();

alter table public.exercises enable row level security;
alter table public.workout_programs enable row level security;
alter table public.workout_program_weeks enable row level security;
alter table public.workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.athlete_program_assignments enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;
alter table public.personal_records enable row level security;

revoke all on table public.exercises from anon;
revoke all on table public.workout_programs from anon;
revoke all on table public.workout_program_weeks from anon;
revoke all on table public.workouts from anon;
revoke all on table public.workout_exercises from anon;
revoke all on table public.athlete_program_assignments from anon;
revoke all on table public.workout_sessions from anon;
revoke all on table public.workout_sets from anon;
revoke all on table public.personal_records from anon;

grant select, insert, update, delete on table public.exercises to authenticated;
grant select, insert, update, delete on table public.workout_programs to authenticated;
grant select, insert, update, delete on table public.workout_program_weeks to authenticated;
grant select, insert, update, delete on table public.workouts to authenticated;
grant select, insert, update, delete on table public.workout_exercises to authenticated;
grant select, insert, update, delete on table public.athlete_program_assignments to authenticated;
grant select, insert, update, delete on table public.workout_sessions to authenticated;
grant select, insert, update, delete on table public.workout_sets to authenticated;
grant select, insert, update, delete on table public.personal_records to authenticated;

create or replace function public.is_coach(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.coaches
    where user_id = check_user_id
  );
$$;

create or replace function public.is_athlete(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.athletes
    where user_id = check_user_id
  );
$$;

create or replace function public.athlete_owns_profile(
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
    select 1 from public.athletes
    where id = check_athlete_id
      and user_id = check_user_id
  );
$$;

create or replace function public.coach_owns_program(
  check_program_id uuid,
  check_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.workout_programs
    where id = check_program_id
      and coach_user_id = check_user_id
  );
$$;

create or replace function public.athlete_has_program(
  check_program_id uuid,
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
    from public.athlete_program_assignments assignment
    join public.athletes athlete on athlete.id = assignment.athlete_id
    where assignment.program_id = check_program_id
      and athlete.user_id = check_user_id
      and assignment.status in ('scheduled', 'active', 'completed')
  );
$$;

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
    from public.athlete_program_assignments assignment
    join public.workout_programs program
      on program.id = assignment.program_id
    where assignment.athlete_id = check_athlete_id
      and program.coach_user_id = check_user_id
  );
$$;

revoke all on function public.is_coach(uuid) from public;
revoke all on function public.is_athlete(uuid) from public;
revoke all on function public.athlete_owns_profile(uuid, uuid) from public;
revoke all on function public.coach_owns_program(uuid, uuid) from public;
revoke all on function public.athlete_has_program(uuid, uuid) from public;
revoke all on function public.coach_manages_athlete(uuid, uuid) from public;
grant execute on function public.is_coach(uuid) to authenticated;
grant execute on function public.is_athlete(uuid) to authenticated;
grant execute on function public.athlete_owns_profile(uuid, uuid) to authenticated;
grant execute on function public.coach_owns_program(uuid, uuid) to authenticated;
grant execute on function public.athlete_has_program(uuid, uuid) to authenticated;
grant execute on function public.coach_manages_athlete(uuid, uuid) to authenticated;

drop policy "Coaches can view athlete profiles" on public.athletes;
create policy "Assigned coaches can view athlete profiles"
on public.athletes for select to authenticated
using (public.coach_manages_athlete(id, (select auth.uid())));

create policy "Authenticated athletes can view exercises"
on public.exercises for select to authenticated
using (public.is_athlete((select auth.uid())));
create policy "Coaches can view exercises"
on public.exercises for select to authenticated
using (public.is_coach((select auth.uid())));
create policy "Coaches can create exercises"
on public.exercises for insert to authenticated
with check (created_by = (select auth.uid()));
create policy "Coaches can update their exercises"
on public.exercises for update to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));
create policy "Coaches can delete their exercises"
on public.exercises for delete to authenticated
using (created_by = (select auth.uid()));

create policy "Coaches can manage their programs"
on public.workout_programs for all to authenticated
using (coach_user_id = (select auth.uid()))
with check (coach_user_id = (select auth.uid()));
create policy "Athletes can view assigned programs"
on public.workout_programs for select to authenticated
using (public.athlete_has_program(id, (select auth.uid())));

create policy "Coaches can manage their program weeks"
on public.workout_program_weeks for all to authenticated
using (public.coach_owns_program(program_id, (select auth.uid())))
with check (public.coach_owns_program(program_id, (select auth.uid())));
create policy "Athletes can view assigned program weeks"
on public.workout_program_weeks for select to authenticated
using (public.athlete_has_program(program_id, (select auth.uid())));

create policy "Coaches can manage their workouts"
on public.workouts for all to authenticated
using (
  exists (
    select 1 from public.workout_program_weeks week
    where week.id = program_week_id
      and public.coach_owns_program(week.program_id, (select auth.uid()))
  )
)
with check (
  exists (
    select 1 from public.workout_program_weeks week
    where week.id = program_week_id
      and public.coach_owns_program(week.program_id, (select auth.uid()))
  )
);
create policy "Athletes can view assigned workouts"
on public.workouts for select to authenticated
using (
  exists (
    select 1 from public.workout_program_weeks week
    where week.id = program_week_id
      and public.athlete_has_program(week.program_id, (select auth.uid()))
  )
);

create policy "Coaches can manage their workout exercises"
on public.workout_exercises for all to authenticated
using (
  exists (
    select 1
    from public.workouts workout
    join public.workout_program_weeks week
      on week.id = workout.program_week_id
    where workout.id = workout_id
      and public.coach_owns_program(week.program_id, (select auth.uid()))
  )
)
with check (
  exists (
    select 1
    from public.workouts workout
    join public.workout_program_weeks week
      on week.id = workout.program_week_id
    where workout.id = workout_id
      and public.coach_owns_program(week.program_id, (select auth.uid()))
  )
);
create policy "Athletes can view assigned workout exercises"
on public.workout_exercises for select to authenticated
using (
  exists (
    select 1
    from public.workouts workout
    join public.workout_program_weeks week
      on week.id = workout.program_week_id
    where workout.id = workout_id
      and public.athlete_has_program(week.program_id, (select auth.uid()))
  )
);

create policy "Athletes can view their assignments"
on public.athlete_program_assignments for select to authenticated
using (public.athlete_owns_profile(athlete_id, (select auth.uid())));
create policy "Coaches can manage assignments for their programs"
on public.athlete_program_assignments for all to authenticated
using (
  public.coach_owns_program(program_id, (select auth.uid()))
  and assigned_by = (select auth.uid())
)
with check (
  public.coach_owns_program(program_id, (select auth.uid()))
  and assigned_by = (select auth.uid())
);

create policy "Athletes can manage their workout sessions"
on public.workout_sessions for all to authenticated
using (public.athlete_owns_profile(athlete_id, (select auth.uid())))
with check (public.athlete_owns_profile(athlete_id, (select auth.uid())));
create policy "Coaches can view managed athlete sessions"
on public.workout_sessions for select to authenticated
using (public.coach_manages_athlete(athlete_id, (select auth.uid())));

create policy "Athletes can manage their workout sets"
on public.workout_sets for all to authenticated
using (
  exists (
    select 1 from public.workout_sessions session
    where session.id = session_id
      and public.athlete_owns_profile(
        session.athlete_id,
        (select auth.uid())
      )
  )
)
with check (
  exists (
    select 1 from public.workout_sessions session
    where session.id = session_id
      and public.athlete_owns_profile(
        session.athlete_id,
        (select auth.uid())
      )
  )
);
create policy "Coaches can view managed athlete sets"
on public.workout_sets for select to authenticated
using (
  exists (
    select 1 from public.workout_sessions session
    where session.id = session_id
      and public.coach_manages_athlete(
        session.athlete_id,
        (select auth.uid())
      )
  )
);

create policy "Athletes can manage their personal records"
on public.personal_records for all to authenticated
using (public.athlete_owns_profile(athlete_id, (select auth.uid())))
with check (public.athlete_owns_profile(athlete_id, (select auth.uid())));
create policy "Coaches can view managed athlete personal records"
on public.personal_records for select to authenticated
using (public.coach_manages_athlete(athlete_id, (select auth.uid())));
