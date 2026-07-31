create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 120),
  slug text not null unique
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  owner_user_id uuid not null references auth.users (id) on delete restrict,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null default '',
  email text not null default '',
  roles text[] not null default '{}'::text[],
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id),
  check (email = '' or email = lower(trim(email))),
  check (
    roles <@ array[
      'organization_owner', 'administrator', 'head_coach',
      'assistant_coach', 'strength_coach', 'athletic_trainer',
      'athlete', 'parent'
    ]::text[]
  ),
  check (cardinality(roles) > 0)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  age_group text not null default '',
  archived_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  team_id uuid not null references public.teams (id) on delete cascade,
  organization_member_id uuid not null
    references public.organization_members (id) on delete cascade,
  role text not null check (
    role in (
      'head_coach', 'assistant_coach', 'strength_coach',
      'athletic_trainer', 'athlete', 'parent'
    )
  ),
  athlete_id uuid references public.athletes (id) on delete cascade,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (role in ('athlete', 'parent') and athlete_id is not null)
    or (
      role not in ('athlete', 'parent')
      and athlete_id is null
    )
  )
);

create unique index team_members_identity_idx
  on public.team_members (
    team_id,
    organization_member_id,
    role,
    coalesce(athlete_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where deleted_at is null;

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 100),
  starts_on date not null,
  ends_on date not null,
  archived_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name),
  check (ends_on >= starts_on)
);

create table public.season_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  season_id uuid not null references public.seasons (id) on delete cascade,
  team_id uuid not null references public.teams (id) on delete cascade,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index season_assignments_active_identity_idx
  on public.season_assignments (season_id, team_id, athlete_id)
  where deleted_at is null;

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  email text not null,
  roles text[] not null,
  team_ids uuid[] not null default '{}'::uuid[],
  token_hash text not null unique,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked', 'expired')),
  invited_by uuid not null references auth.users (id) on delete restrict,
  expires_at timestamptz not null,
  responded_at timestamptz,
  revoked_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (email = lower(trim(email))),
  check (cardinality(roles) > 0),
  check (
    roles <@ array[
      'administrator', 'head_coach', 'assistant_coach',
      'strength_coach', 'athletic_trainer', 'athlete', 'parent'
    ]::text[]
  )
);

create unique index invitations_pending_email_idx
  on public.invitations (organization_id, email)
  where status = 'pending' and deleted_at is null;

create index organization_members_user_idx
  on public.organization_members (user_id, status)
  where deleted_at is null;
create index organization_members_org_idx
  on public.organization_members (organization_id, status)
  where deleted_at is null;
create index teams_org_active_idx
  on public.teams (organization_id, archived_at)
  where deleted_at is null;
create index team_members_member_idx
  on public.team_members (organization_member_id)
  where deleted_at is null;
create index team_members_athlete_idx
  on public.team_members (athlete_id, team_id)
  where deleted_at is null;
create index seasons_org_dates_idx
  on public.seasons (organization_id, starts_on desc)
  where deleted_at is null;
create index season_assignments_athlete_idx
  on public.season_assignments (athlete_id, season_id)
  where deleted_at is null;
create index season_assignments_team_idx
  on public.season_assignments (team_id, season_id)
  where deleted_at is null;
create index invitations_org_status_idx
  on public.invitations (organization_id, status, expires_at);

create trigger set_organizations_updated_at before update
on public.organizations for each row execute function public.set_updated_at();
create trigger set_organization_members_updated_at before update
on public.organization_members for each row execute function public.set_updated_at();
create trigger set_teams_updated_at before update
on public.teams for each row execute function public.set_updated_at();
create trigger set_team_members_updated_at before update
on public.team_members for each row execute function public.set_updated_at();
create trigger set_seasons_updated_at before update
on public.seasons for each row execute function public.set_updated_at();
create trigger set_season_assignments_updated_at before update
on public.season_assignments for each row execute function public.set_updated_at();
create trigger set_invitations_updated_at before update
on public.invitations for each row execute function public.set_updated_at();

create or replace function public.is_organization_member(
  check_organization_id uuid,
  check_user_id uuid
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_members member
    where member.organization_id = check_organization_id
      and member.user_id = check_user_id
      and member.status = 'active'
      and member.deleted_at is null
  );
$$;

create or replace function public.has_organization_role(
  check_organization_id uuid,
  check_user_id uuid,
  check_roles text[]
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.organization_members member
    where member.organization_id = check_organization_id
      and member.user_id = check_user_id
      and member.status = 'active'
      and member.deleted_at is null
      and member.roles && check_roles
  );
$$;

create or replace function public.can_administer_organization(
  check_organization_id uuid,
  check_user_id uuid
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select public.has_organization_role(
    check_organization_id,
    check_user_id,
    array['organization_owner', 'administrator']::text[]
  );
$$;

create or replace function public.is_assigned_to_team(
  check_team_id uuid,
  check_user_id uuid,
  check_roles text[]
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.team_members team_member
    join public.organization_members member
      on member.id = team_member.organization_member_id
    where team_member.team_id = check_team_id
      and team_member.role = any(check_roles)
      and team_member.deleted_at is null
      and member.user_id = check_user_id
      and member.status = 'active'
      and member.deleted_at is null
  );
$$;

create or replace function public.can_staff_access_athlete(
  check_athlete_id uuid,
  check_user_id uuid
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.team_members athlete_member
    where athlete_member.athlete_id = check_athlete_id
      and athlete_member.role = 'athlete'
      and athlete_member.deleted_at is null
      and (
        public.can_administer_organization(
          athlete_member.organization_id,
          check_user_id
        )
        or public.is_assigned_to_team(
          athlete_member.team_id,
          check_user_id,
          array[
            'head_coach', 'assistant_coach',
            'strength_coach', 'athletic_trainer'
          ]::text[]
        )
      )
  )
  or exists (
    select 1
    from public.season_assignments assignment
    where assignment.athlete_id = check_athlete_id
      and assignment.status = 'active'
      and assignment.deleted_at is null
      and (
        public.can_administer_organization(
          assignment.organization_id,
          check_user_id
        )
        or public.is_assigned_to_team(
          assignment.team_id,
          check_user_id,
          array[
            'head_coach', 'assistant_coach',
            'strength_coach', 'athletic_trainer'
          ]::text[]
        )
      )
  );
$$;

create or replace function public.parent_can_view_athlete(
  check_athlete_id uuid,
  check_user_id uuid
)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.team_members team_member
    join public.organization_members member
      on member.id = team_member.organization_member_id
    where team_member.athlete_id = check_athlete_id
      and team_member.role = 'parent'
      and team_member.deleted_at is null
      and member.user_id = check_user_id
      and member.status = 'active'
      and member.deleted_at is null
  );
$$;

revoke all on function public.is_organization_member(uuid, uuid)
  from public;
revoke all on function public.has_organization_role(uuid, uuid, text[])
  from public;
revoke all on function public.can_administer_organization(uuid, uuid)
  from public;
revoke all on function public.is_assigned_to_team(uuid, uuid, text[])
  from public;
revoke all on function public.can_staff_access_athlete(uuid, uuid)
  from public;
revoke all on function public.parent_can_view_athlete(uuid, uuid)
  from public;

grant execute on function public.is_organization_member(uuid, uuid)
  to authenticated;
grant execute on function public.has_organization_role(uuid, uuid, text[])
  to authenticated;
grant execute on function public.can_administer_organization(uuid, uuid)
  to authenticated;
grant execute on function public.is_assigned_to_team(uuid, uuid, text[])
  to authenticated;
grant execute on function public.can_staff_access_athlete(uuid, uuid)
  to authenticated;
grant execute on function public.parent_can_view_athlete(uuid, uuid)
  to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.seasons enable row level security;
alter table public.season_assignments enable row level security;
alter table public.invitations enable row level security;

revoke all on public.organizations from anon;
revoke all on public.organization_members from anon;
revoke all on public.teams from anon;
revoke all on public.team_members from anon;
revoke all on public.seasons from anon;
revoke all on public.season_assignments from anon;
revoke all on public.invitations from anon;
grant select, insert, update on public.organizations to authenticated;
grant select, insert, update on public.organization_members to authenticated;
grant select, insert, update on public.teams to authenticated;
grant select, insert, update on public.team_members to authenticated;
grant select, insert, update on public.seasons to authenticated;
grant select, insert, update on public.season_assignments to authenticated;
grant select, insert, update on public.invitations to authenticated;

create policy "Members view organizations"
on public.organizations for select to authenticated using (
  deleted_at is null
  and public.is_organization_member(id, (select auth.uid()))
);
create policy "Users create owned organizations"
on public.organizations for insert to authenticated with check (
  owner_user_id = (select auth.uid()) and deleted_at is null
);
create policy "Owners and administrators update organizations"
on public.organizations for update to authenticated using (
  public.can_administer_organization(id, (select auth.uid()))
) with check (
  public.can_administer_organization(id, (select auth.uid()))
);

create policy "Members view organization memberships"
on public.organization_members for select to authenticated using (
  public.is_organization_member(organization_id, (select auth.uid()))
);
create policy "Owners create initial membership"
on public.organization_members for insert to authenticated with check (
  user_id = (select auth.uid())
  and roles = array['organization_owner']::text[]
  and exists (
    select 1 from public.organizations organization
    where organization.id = organization_id
      and organization.owner_user_id = (select auth.uid())
  )
);
create policy "Organization administrators add memberships"
on public.organization_members for insert to authenticated with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators update memberships"
on public.organization_members for update to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
) with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);

create policy "Organization members view teams"
on public.teams for select to authenticated using (
  deleted_at is null
  and (
    public.can_administer_organization(
      organization_id,
      (select auth.uid())
    )
    or exists (
      select 1 from public.team_members team_member
      join public.organization_members member
        on member.id = team_member.organization_member_id
      where team_member.team_id = teams.id
        and team_member.deleted_at is null
        and member.user_id = (select auth.uid())
        and member.deleted_at is null
    )
  )
);
create policy "Organization administrators create teams"
on public.teams for insert to authenticated with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators update teams"
on public.teams for update to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
) with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);

create policy "Assigned members view team memberships"
on public.team_members for select to authenticated using (
  deleted_at is null
  and (
    public.can_administer_organization(
      organization_id,
      (select auth.uid())
    )
    or exists (
      select 1 from public.organization_members member
      where member.id = organization_member_id
        and member.user_id = (select auth.uid())
    )
    or public.is_assigned_to_team(
      team_id,
      (select auth.uid()),
      array[
        'head_coach', 'assistant_coach',
        'strength_coach', 'athletic_trainer'
      ]::text[]
    )
  )
);
create policy "Organization administrators manage team memberships"
on public.team_members for insert to authenticated with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators update team memberships"
on public.team_members for update to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
) with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);

create policy "Organization members view seasons"
on public.seasons for select to authenticated using (
  deleted_at is null
  and public.is_organization_member(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators create seasons"
on public.seasons for insert to authenticated with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators update seasons"
on public.seasons for update to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
) with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);

create policy "Members view relevant season assignments"
on public.season_assignments for select to authenticated using (
  deleted_at is null
  and (
    public.can_administer_organization(
      organization_id,
      (select auth.uid())
    )
    or public.athlete_owns_profile(athlete_id, (select auth.uid()))
    or public.can_staff_access_athlete(athlete_id, (select auth.uid()))
    or public.parent_can_view_athlete(athlete_id, (select auth.uid()))
  )
);
create policy "Organization administrators create season assignments"
on public.season_assignments for insert to authenticated with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators update season assignments"
on public.season_assignments for update to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
) with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);

create policy "Organization administrators view invitations"
on public.invitations for select to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators create invitations"
on public.invitations for insert to authenticated with check (
  invited_by = (select auth.uid())
  and public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);
create policy "Organization administrators update invitations"
on public.invitations for update to authenticated using (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
) with check (
  public.can_administer_organization(
    organization_id,
    (select auth.uid())
  )
);

drop policy if exists "Coaches can view athlete profiles"
on public.athletes;

create policy "Organization staff view assigned athletes"
on public.athletes for select to authenticated using (
  public.can_staff_access_athlete(id, (select auth.uid()))
);

create policy "Parents view linked athlete profiles"
on public.athletes for select to authenticated using (
  public.parent_can_view_athlete(id, (select auth.uid()))
);

create policy "Parents view linked workout sessions"
on public.workout_sessions for select to authenticated using (
  public.parent_can_view_athlete(athlete_id, (select auth.uid()))
);

create policy "Parents view linked workout sets"
on public.workout_sets for select to authenticated using (
  exists (
    select 1 from public.workout_sessions session
    where session.id = session_id
      and public.parent_can_view_athlete(
        session.athlete_id,
        (select auth.uid())
      )
  )
);

create policy "Parents view linked testing sessions"
on public.testing_sessions for select to authenticated using (
  public.parent_can_view_athlete(athlete_id, (select auth.uid()))
);

create policy "Parents view linked testing results"
on public.testing_results for select to authenticated using (
  public.parent_can_view_athlete(athlete_id, (select auth.uid()))
);
