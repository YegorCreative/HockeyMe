revoke insert on public.organizations from authenticated;
revoke insert on public.organization_members from authenticated;
revoke update on public.organizations from authenticated;
grant update (name, slug, deleted_at) on public.organizations
  to authenticated;

create or replace function public.create_organization(
  organization_name text,
  organization_slug text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if char_length(trim(organization_name)) not between 1 and 120
    or organization_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  then
    raise exception 'Invalid organization name or slug';
  end if;

  insert into public.organizations (name, slug, owner_user_id)
  values (trim(organization_name), organization_slug, (select auth.uid()))
  returning id into new_id;

  insert into public.organization_members (
    organization_id,
    user_id,
    display_name,
    email,
    roles
  ) values (
    new_id,
    (select auth.uid()),
    coalesce((select auth.jwt() -> 'user_metadata' ->> 'full_name'), ''),
    lower(coalesce((select auth.jwt() ->> 'email'), '')),
    array['organization_owner']::text[]
  );

  insert into public.coaches (user_id)
  values ((select auth.uid()))
  on conflict (user_id) do nothing;

  return new_id;
end;
$$;

revoke all on function public.create_organization(text, text) from public;
grant execute on function public.create_organization(text, text)
  to authenticated;

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
begin
  select owner_user_id into old_owner_user_id
  from public.organizations
  where id = check_organization_id
    and deleted_at is null
  for update;

  if old_owner_user_id is distinct from (select auth.uid()) then
    raise exception 'Only the current owner can transfer ownership';
  end if;

  if not public.is_organization_member(
    check_organization_id,
    new_owner_user_id
  ) then
    raise exception 'New owner must be an active organization member';
  end if;

  update public.organization_members
  set roles = array_remove(roles, 'organization_owner')
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

create or replace function public.create_organization_invitation(
  check_organization_id uuid,
  invite_email text,
  invite_roles text[],
  invite_team_ids uuid[],
  expires_in_hours integer default 168
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(trim(invite_email));
  raw_token text;
begin
  if not public.can_administer_organization(
    check_organization_id,
    (select auth.uid())
  ) then
    raise exception 'Not authorized to invite organization members';
  end if;

  if normalized_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
    or cardinality(invite_roles) = 0
    or expires_in_hours not between 1 and 720
  then
    raise exception 'Invalid invitation';
  end if;

  if not invite_roles <@ array[
    'administrator', 'head_coach', 'assistant_coach',
    'strength_coach', 'athletic_trainer', 'athlete', 'parent'
  ]::text[] then
    raise exception 'Invalid invitation role';
  end if;

  if exists (
    select 1 from unnest(invite_team_ids) team_id
    left join public.teams team
      on team.id = team_id
      and team.organization_id = check_organization_id
      and team.deleted_at is null
    where team.id is null
  ) then
    raise exception 'Invitation contains a team from another organization';
  end if;

  raw_token := encode(extensions.gen_random_bytes(32), 'hex');

  insert into public.invitations (
    organization_id,
    email,
    roles,
    team_ids,
    token_hash,
    invited_by,
    expires_at
  ) values (
    check_organization_id,
    normalized_email,
    invite_roles,
    invite_team_ids,
    encode(extensions.digest(raw_token, 'sha256'), 'hex'),
    (select auth.uid()),
    now() + make_interval(hours => expires_in_hours)
  );

  return raw_token;
end;
$$;

revoke all on function public.create_organization_invitation(
  uuid, text, text[], uuid[], integer
) from public;
grant execute on function public.create_organization_invitation(
  uuid, text, text[], uuid[], integer
) to authenticated;

create or replace function public.respond_to_organization_invitation(
  raw_token text,
  accept_invitation boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation_row public.invitations%rowtype;
  member_id uuid;
  user_email text := lower(coalesce((select auth.jwt() ->> 'email'), ''));
  role_value text;
  team_value uuid;
  athlete_value uuid;
begin
  select * into invitation_row
  from public.invitations
  where token_hash = encode(
      extensions.digest(raw_token, 'sha256'),
      'hex'
    )
    and status = 'pending'
    and deleted_at is null
  for update;

  if invitation_row.id is null then
    raise exception 'Invitation is invalid or no longer available';
  end if;
  if invitation_row.expires_at <= now() then
    update public.invitations
    set status = 'expired', responded_at = now()
    where id = invitation_row.id;
    raise exception 'Invitation has expired';
  end if;
  if invitation_row.email <> user_email then
    raise exception 'Invitation email does not match signed-in user';
  end if;

  if not accept_invitation then
    update public.invitations
    set status = 'declined', responded_at = now()
    where id = invitation_row.id;
    return invitation_row.organization_id;
  end if;

  insert into public.organization_members (
    organization_id,
    user_id,
    email,
    roles
  ) values (
    invitation_row.organization_id,
    (select auth.uid()),
    user_email,
    invitation_row.roles
  )
  on conflict (organization_id, user_id) do update
  set roles = (
    select array_agg(distinct role)
    from unnest(
      public.organization_members.roles || excluded.roles
    ) role
  ),
  status = 'active',
  deleted_at = null
  returning id into member_id;

  if 'athlete' = any(invitation_row.roles) then
    select id into athlete_value from public.athletes
    where user_id = (select auth.uid());
    if athlete_value is null then
      raise exception 'Complete athlete onboarding before accepting';
    end if;
  end if;

  if invitation_row.roles && array[
    'administrator', 'head_coach', 'assistant_coach',
    'strength_coach', 'athletic_trainer'
  ]::text[] then
    insert into public.coaches (user_id)
    values ((select auth.uid()))
    on conflict (user_id) do nothing;
  end if;

  foreach team_value in array invitation_row.team_ids loop
    foreach role_value in array invitation_row.roles loop
      if role_value in (
        'head_coach', 'assistant_coach', 'strength_coach',
        'athletic_trainer', 'athlete'
      ) then
        insert into public.team_members (
          organization_id,
          team_id,
          organization_member_id,
          role,
          athlete_id
        ) values (
          invitation_row.organization_id,
          team_value,
          member_id,
          role_value,
          case when role_value = 'athlete'
            then athlete_value else null end
        )
        on conflict do nothing;
      end if;
    end loop;
  end loop;

  update public.invitations
  set status = 'accepted', responded_at = now()
  where id = invitation_row.id;

  return invitation_row.organization_id;
end;
$$;

revoke all on function public.respond_to_organization_invitation(
  text, boolean
) from public;
grant execute on function public.respond_to_organization_invitation(
  text, boolean
) to authenticated;

create or replace function public.clone_team_to_season(
  source_team_id uuid,
  target_season_id uuid,
  cloned_team_name text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_team public.teams%rowtype;
  target_season public.seasons%rowtype;
  cloned_team_id uuid;
begin
  select * into source_team
  from public.teams
  where id = source_team_id
    and deleted_at is null;

  select * into target_season
  from public.seasons
  where id = target_season_id
    and deleted_at is null;

  if source_team.id is null
    or target_season.id is null
    or source_team.organization_id <> target_season.organization_id
  then
    raise exception 'Team and season must belong to the same organization';
  end if;

  if not public.can_administer_organization(
    source_team.organization_id,
    (select auth.uid())
  ) then
    raise exception 'Not authorized to clone this team';
  end if;

  insert into public.teams (organization_id, name, age_group)
  values (
    source_team.organization_id,
    trim(cloned_team_name),
    source_team.age_group
  )
  returning id into cloned_team_id;

  insert into public.team_members (
    organization_id,
    team_id,
    organization_member_id,
    role,
    athlete_id
  )
  select organization_id,
    cloned_team_id,
    organization_member_id,
    role,
    athlete_id
  from public.team_members
  where team_id = source_team_id
    and deleted_at is null;

  insert into public.season_assignments (
    organization_id,
    season_id,
    team_id,
    athlete_id
  )
  select distinct source_team.organization_id,
    target_season_id,
    cloned_team_id,
    athlete_id
  from public.team_members
  where team_id = source_team_id
    and role = 'athlete'
    and athlete_id is not null
    and deleted_at is null
  on conflict do nothing;

  return cloned_team_id;
end;
$$;

revoke all on function public.clone_team_to_season(uuid, uuid, text)
  from public;
grant execute on function public.clone_team_to_season(uuid, uuid, text)
  to authenticated;

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
    ) then
      raise exception 'Team membership organization mismatch';
    end if;
  elsif tg_table_name = 'season_assignments' then
    if not exists (
      select 1
      from public.teams team
      join public.seasons season
        on season.organization_id = team.organization_id
      where team.id = new.team_id
        and season.id = new.season_id
        and team.organization_id = new.organization_id
    ) then
      raise exception 'Season assignment organization mismatch';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.validate_organization_scope() from public;

create trigger validate_team_member_organization
before insert or update on public.team_members
for each row execute function public.validate_organization_scope();

create trigger validate_season_assignment_organization
before insert or update on public.season_assignments
for each row execute function public.validate_organization_scope();

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
  select public.can_staff_access_athlete(
    check_athlete_id,
    check_user_id
  )
  or exists (
    select 1
    from public.coach_athlete_links link
    where link.athlete_id = check_athlete_id
      and link.coach_user_id = check_user_id
  );
$$;
