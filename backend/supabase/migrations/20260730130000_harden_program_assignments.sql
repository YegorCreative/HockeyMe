create unique index athlete_program_assignments_one_current_idx
on public.athlete_program_assignments (athlete_id, program_id)
where status in ('scheduled', 'active');

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
    join public.athletes athlete
      on athlete.id = assignment.athlete_id
    join public.workout_programs program
      on program.id = assignment.program_id
    where assignment.program_id = check_program_id
      and athlete.user_id = check_user_id
      and assignment.status in ('scheduled', 'active', 'completed')
      and program.status = 'active'
  );
$$;
