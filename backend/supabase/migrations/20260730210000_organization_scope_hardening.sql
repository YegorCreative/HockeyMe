create or replace function public.validate_organization_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_table_name = 'team_members' then
    if not exists (
      select 1
      from public.teams team
      join public.organization_members member
        on member.organization_id = team.organization_id
      where team.id = new.team_id
        and member.id = new.organization_member_id
        and team.organization_id = new.organization_id
        and team.deleted_at is null
        and member.deleted_at is null
        and member.status = 'active'
    ) then
      raise exception 'Team membership organization mismatch';
    end if;

    if new.athlete_id is not null and not exists (
      select 1
      from public.team_members athlete_member
      where athlete_member.organization_id = new.organization_id
        and athlete_member.athlete_id = new.athlete_id
        and athlete_member.role = 'athlete'
        and athlete_member.deleted_at is null
        and (
          new.role = 'parent'
          or athlete_member.team_id = new.team_id
        )
        and (
          new.role = 'parent'
          or athlete_member.id = new.id
          or tg_op = 'INSERT'
        )
    ) and not (
      new.role = 'athlete'
      and exists (
        select 1
        from public.athletes athlete
        join public.organization_members member
          on member.user_id = athlete.user_id
          and member.organization_id = new.organization_id
          and 'athlete' = any(member.roles)
          and member.status = 'active'
          and member.deleted_at is null
        where athlete.id = new.athlete_id
          and member.id = new.organization_member_id
      )
    ) then
      raise exception 'Athlete link is outside this organization or team';
    end if;
  elsif tg_table_name = 'season_assignments' then
    if not exists (
      select 1
      from public.teams team
      join public.seasons season
        on season.organization_id = team.organization_id
      join public.team_members athlete_member
        on athlete_member.team_id = team.id
        and athlete_member.athlete_id = new.athlete_id
        and athlete_member.role = 'athlete'
        and athlete_member.deleted_at is null
      where team.id = new.team_id
        and season.id = new.season_id
        and team.organization_id = new.organization_id
        and team.deleted_at is null
        and season.deleted_at is null
    ) then
      raise exception 'Season assignment organization mismatch';
    end if;
  end if;
  return new;
end;
$$;

revoke update on public.organization_members from authenticated;
grant update (display_name, email, roles, status, deleted_at)
  on public.organization_members to authenticated;

revoke update on public.teams from authenticated;
grant update (name, age_group, archived_at, deleted_at)
  on public.teams to authenticated;

revoke update on public.seasons from authenticated;
grant update (name, starts_on, ends_on, archived_at, deleted_at)
  on public.seasons to authenticated;

revoke insert on public.invitations from authenticated;
