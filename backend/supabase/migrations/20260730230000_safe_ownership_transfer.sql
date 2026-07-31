create or replace function public.transfer_organization_ownership(
  check_organization_id uuid,
  new_owner_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_owner_user_id uuid;
  old_owner_roles text[];
begin
  select owner_user_id into old_owner_user_id
  from public.organizations
  where id = check_organization_id
    and deleted_at is null
  for update;

  if old_owner_user_id is distinct from (select auth.uid()) then
    raise exception 'Only the current owner can transfer ownership';
  end if;

  if new_owner_user_id = old_owner_user_id then
    raise exception 'New owner must be a different active member';
  end if;

  if not public.is_organization_member(
    check_organization_id,
    new_owner_user_id
  ) then
    raise exception 'New owner must be an active organization member';
  end if;

  select array_remove(roles, 'organization_owner')
  into old_owner_roles
  from public.organization_members
  where organization_id = check_organization_id
    and user_id = old_owner_user_id
  for update;

  if cardinality(old_owner_roles) = 0 then
    old_owner_roles := array['administrator']::text[];
  end if;

  update public.organization_members
  set roles = old_owner_roles
  where organization_id = check_organization_id
    and user_id = old_owner_user_id;

  update public.organization_members
  set roles = array_append(
    array_remove(roles, 'organization_owner'),
    'organization_owner'
  )
  where organization_id = check_organization_id
    and user_id = new_owner_user_id;

  update public.organizations
  set owner_user_id = new_owner_user_id
  where id = check_organization_id;

  return true;
end;
$$;

revoke all on function public.transfer_organization_ownership(uuid, uuid)
  from public;
grant execute on function public.transfer_organization_ownership(uuid, uuid)
  to authenticated;

create or replace function public.move_athlete_to_team(
  check_organization_id uuid,
  check_athlete_id uuid,
  check_season_id uuid,
  from_team_id uuid,
  to_team_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  athlete_member_id uuid;
begin
  if not public.can_administer_organization(
    check_organization_id,
    (select auth.uid())
  ) then
    raise exception 'Not authorized to move athletes';
  end if;

  if not exists (
    select 1 from public.seasons season
    where season.id = check_season_id
      and season.organization_id = check_organization_id
      and season.deleted_at is null
  ) or not exists (
    select 1 from public.teams team
    where team.id = to_team_id
      and team.organization_id = check_organization_id
      and team.deleted_at is null
      and team.archived_at is null
  ) then
    raise exception 'Invalid target team or season';
  end if;

  select member.id into athlete_member_id
  from public.organization_members member
  join public.athletes athlete on athlete.user_id = member.user_id
  where member.organization_id = check_organization_id
    and athlete.id = check_athlete_id
    and 'athlete' = any(member.roles)
    and member.status = 'active'
    and member.deleted_at is null;

  if athlete_member_id is null then
    raise exception 'Athlete is not an active organization member';
  end if;

  update public.season_assignments
  set deleted_at = now()
  where organization_id = check_organization_id
    and season_id = check_season_id
    and team_id = from_team_id
    and athlete_id = check_athlete_id
    and deleted_at is null;

  update public.team_members
  set deleted_at = now()
  where organization_id = check_organization_id
    and team_id = from_team_id
    and athlete_id = check_athlete_id
    and role = 'athlete'
    and deleted_at is null;

  insert into public.team_members (
    organization_id,
    team_id,
    organization_member_id,
    role,
    athlete_id
  ) values (
    check_organization_id,
    to_team_id,
    athlete_member_id,
    'athlete',
    check_athlete_id
  )
  on conflict do nothing;

  insert into public.season_assignments (
    organization_id,
    season_id,
    team_id,
    athlete_id
  ) values (
    check_organization_id,
    check_season_id,
    to_team_id,
    check_athlete_id
  )
  on conflict do nothing;
end;
$$;

revoke all on function public.move_athlete_to_team(
  uuid, uuid, uuid, uuid, uuid
) from public;
grant execute on function public.move_athlete_to_team(
  uuid, uuid, uuid, uuid, uuid
) to authenticated;
