alter table public.workout_exercises
  add column tempo text,
  add column coach_cues text;

alter table public.workout_program_weeks
  drop constraint workout_program_weeks_program_number_unique;
alter table public.workout_program_weeks
  add constraint workout_program_weeks_program_number_unique
  unique (program_id, week_number)
  deferrable initially deferred;

alter table public.workouts
  drop constraint workouts_week_day_unique;
alter table public.workouts
  add constraint workouts_week_day_unique
  unique (program_week_id, day_number, sort_order)
  deferrable initially deferred;

alter table public.workout_exercises
  drop constraint workout_exercises_workout_order_unique;
alter table public.workout_exercises
  add constraint workout_exercises_workout_order_unique
  unique (workout_id, sort_order)
  deferrable initially deferred;

create or replace function public.prevent_published_program_deletion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'active'
    and exists (
      select 1
      from public.athlete_program_assignments assignment
      where assignment.program_id = old.id
        and assignment.status in ('scheduled', 'active')
    )
  then
    raise exception
      'Published programs with active athlete assignments cannot be deleted';
  end if;

  return old;
end;
$$;

create trigger workout_programs_prevent_protected_delete
before delete on public.workout_programs
for each row execute function public.prevent_published_program_deletion();

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
  from public.athletes athlete
  where exists (
    select 1
    from public.coaches coach
    where coach.user_id = (select auth.uid())
  );
$$;

revoke all on function public.get_assignable_athletes() from public;
grant execute on function public.get_assignable_athletes() to authenticated;
