drop policy "Athletes update allowed self testing sessions"
on public.testing_sessions;

create policy "Athletes update allowed self testing sessions"
on public.testing_sessions
for update
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
  and exists (
    select 1 from public.testing_protocols protocol
    where protocol.id = protocol_id
      and protocol.status = 'active'
      and protocol.allows_athlete_entry
  )
)
with check (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
  and status in ('scheduled', 'in_progress', 'completed')
  and exists (
    select 1 from public.testing_protocols protocol
    where protocol.id = protocol_id
      and protocol.status = 'active'
      and protocol.allows_athlete_entry
  )
);

create or replace function public.protect_athlete_testing_session_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.athlete_owns_profile(old.athlete_id, (select auth.uid()))
    and not exists (
      select 1 from public.coaches
      where user_id = (select auth.uid())
    )
    and (
      new.protocol_id is distinct from old.protocol_id
      or new.athlete_id is distinct from old.athlete_id
      or new.scheduled_at is distinct from old.scheduled_at
      or new.season_label is distinct from old.season_label
      or new.location is distinct from old.location
      or new.created_by is distinct from old.created_by
      or new.created_at is distinct from old.created_at
    )
  then
    raise exception 'Athletes may only update testing progress';
  end if;
  return new;
end;
$$;

revoke all on function public.protect_athlete_testing_session_fields()
  from public;

create trigger protect_athlete_testing_session_fields
before update on public.testing_sessions
for each row execute function public.protect_athlete_testing_session_fields();
