alter table public.invitations
  add column delivery_status text not null default 'pending'
    check (delivery_status in ('pending', 'sent', 'failed')),
  add column delivered_at timestamptz,
  add column delivery_failure_code text;

create table public.invitation_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations (id) on delete cascade,
  requested_by uuid not null references auth.users (id) on delete cascade,
  email_hash text not null,
  network_hash text not null default '',
  created_at timestamptz not null default now()
);

create index invitation_delivery_attempts_org_time_idx
  on public.invitation_delivery_attempts (organization_id, created_at desc);
create index invitation_delivery_attempts_user_time_idx
  on public.invitation_delivery_attempts (requested_by, created_at desc);
create index invitation_delivery_attempts_network_time_idx
  on public.invitation_delivery_attempts (network_hash, created_at desc);

alter table public.invitation_delivery_attempts enable row level security;
revoke all on public.invitation_delivery_attempts from anon, authenticated;

revoke execute on function public.create_organization_invitation(
  uuid, text, text[], uuid[], integer
) from authenticated;

revoke update on public.invitations from authenticated;

create or replace function public.create_invitation_for_delivery(
  actor_user_id uuid,
  check_organization_id uuid,
  invite_email text,
  invite_roles text[],
  invite_team_ids uuid[],
  expires_in_hours integer,
  request_network_hash text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(trim(invite_email));
  raw_token text;
  invitation_id uuid;
  invitation_expires_at timestamptz;
  organization_name text;
begin
  if not public.can_administer_organization(
    check_organization_id,
    actor_user_id
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
    raise exception 'Invitation contains an invalid team';
  end if;

  if (
    select count(*)
    from public.invitation_delivery_attempts attempt
    where attempt.organization_id = check_organization_id
      and attempt.created_at > now() - interval '1 hour'
  ) >= 25 or (
    select count(*)
    from public.invitation_delivery_attempts attempt
    where attempt.requested_by = actor_user_id
      and attempt.created_at > now() - interval '1 hour'
  ) >= 10 or (
    request_network_hash <> ''
    and (
      select count(*)
      from public.invitation_delivery_attempts attempt
      where attempt.network_hash = request_network_hash
        and attempt.created_at > now() - interval '1 hour'
    ) >= 30
  ) then
    raise exception 'Invitation rate limit exceeded';
  end if;

  insert into public.invitation_delivery_attempts (
    organization_id,
    requested_by,
    email_hash,
    network_hash
  ) values (
    check_organization_id,
    actor_user_id,
    encode(extensions.digest(normalized_email, 'sha256'), 'hex'),
    left(request_network_hash, 128)
  );

  select name into organization_name
  from public.organizations
  where id = check_organization_id and deleted_at is null;

  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  invitation_expires_at := now() + make_interval(hours => expires_in_hours);

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
    actor_user_id,
    invitation_expires_at
  )
  returning id into invitation_id;

  return jsonb_build_object(
    'invitation_id', invitation_id,
    'raw_token', raw_token,
    'email', normalized_email,
    'organization_name', organization_name,
    'expires_at', invitation_expires_at
  );
end;
$$;

revoke all on function public.create_invitation_for_delivery(
  uuid, uuid, text, text[], uuid[], integer, text
) from public;
grant execute on function public.create_invitation_for_delivery(
  uuid, uuid, text, text[], uuid[], integer, text
) to service_role;

create or replace function public.complete_invitation_delivery(
  check_invitation_id uuid,
  was_delivered boolean,
  failure_code text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.invitations
  set delivery_status = case when was_delivered then 'sent' else 'failed' end,
      delivered_at = case when was_delivered then now() else null end,
      delivery_failure_code = case
        when was_delivered then null else left(failure_code, 80)
      end,
      status = case when was_delivered then status else 'revoked' end,
      revoked_at = case when was_delivered then revoked_at else now() end
  where id = check_invitation_id and status = 'pending';
end;
$$;

revoke all on function public.complete_invitation_delivery(
  uuid, boolean, text
) from public;
grant execute on function public.complete_invitation_delivery(
  uuid, boolean, text
) to service_role;

create or replace function public.revoke_organization_invitation(
  check_invitation_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation_organization_id uuid;
begin
  select organization_id into invitation_organization_id
  from public.invitations
  where id = check_invitation_id
    and status = 'pending'
    and deleted_at is null;

  if invitation_organization_id is null
    or not public.can_administer_organization(
      invitation_organization_id,
      (select auth.uid())
    )
  then
    raise exception 'Invitation not found or not authorized';
  end if;

  update public.invitations
  set status = 'revoked', revoked_at = now()
  where id = check_invitation_id;
end;
$$;

revoke all on function public.revoke_organization_invitation(uuid)
  from public;
grant execute on function public.revoke_organization_invitation(uuid)
  to authenticated;

create or replace function public.can_view_organization_member(
  check_member_id uuid,
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
    from public.organization_members target
    where target.id = check_member_id
      and target.deleted_at is null
      and (
        target.user_id = check_user_id
        or public.can_administer_organization(
          target.organization_id,
          check_user_id
        )
        or exists (
          select 1
          from public.team_members target_team
          where target_team.organization_member_id = target.id
            and target_team.deleted_at is null
            and public.is_assigned_to_team(
              target_team.team_id,
              check_user_id,
              array[
                'head_coach', 'assistant_coach',
                'strength_coach', 'athletic_trainer'
              ]::text[]
            )
        )
      )
  );
$$;

revoke all on function public.can_view_organization_member(uuid, uuid)
  from public;
grant execute on function public.can_view_organization_member(uuid, uuid)
  to authenticated;

drop policy if exists "Members view organization memberships"
  on public.organization_members;
create policy "Scoped organization membership visibility"
on public.organization_members for select to authenticated using (
  public.can_view_organization_member(id, (select auth.uid()))
);

drop policy if exists "Organization members view teams" on public.teams;
create policy "Assigned members view teams"
on public.teams for select to authenticated using (
  deleted_at is null
  and (
    public.can_administer_organization(
      organization_id,
      (select auth.uid())
    )
    or public.is_assigned_to_team(
      id,
      (select auth.uid()),
      array[
        'head_coach', 'assistant_coach', 'strength_coach',
        'athletic_trainer', 'athlete', 'parent'
      ]::text[]
    )
  )
);
