create table public.testing_protocols (
  id uuid primary key default gen_random_uuid(),
  coach_user_id uuid not null
    references public.coaches (user_id) on delete cascade,
  parent_protocol_id uuid
    references public.testing_protocols (id) on delete set null,
  name text not null check (char_length(trim(name)) between 1 and 120),
  description text not null default '',
  version integer not null default 1 check (version > 0),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'inactive', 'archived')),
  allows_athlete_entry boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (coach_user_id, name, version)
);

create table public.testing_metrics (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid not null
    references public.testing_protocols (id) on delete cascade,
  metric_key text not null
    check (metric_key ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  name text not null check (char_length(trim(name)) between 1 and 100),
  category text not null check (
    category in (
      'lower_body', 'speed', 'agility', 'strength', 'power',
      'endurance', 'mobility', 'grip', 'body_composition', 'custom'
    )
  ),
  unit text not null check (char_length(trim(unit)) between 1 and 24),
  value_direction text not null default 'higher'
    check (value_direction in ('higher', 'lower')),
  is_required boolean not null default true,
  sort_order integer not null default 0 check (sort_order >= 0),
  instructions text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (protocol_id, metric_key)
);

create table public.testing_sessions (
  id uuid primary key default gen_random_uuid(),
  protocol_id uuid not null
    references public.testing_protocols (id) on delete restrict,
  athlete_id uuid not null
    references public.athletes (id) on delete cascade,
  scheduled_at timestamptz not null,
  completed_at timestamptz,
  season_label text not null default '',
  location text not null default '',
  status text not null default 'scheduled'
    check (status in ('scheduled', 'in_progress', 'completed', 'cancelled')),
  created_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (status = 'completed' and completed_at is not null)
    or (status <> 'completed')
  ),
  unique (protocol_id, athlete_id, scheduled_at)
);

create table public.testing_results (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null
    references public.testing_sessions (id) on delete cascade,
  metric_id uuid not null
    references public.testing_metrics (id) on delete restrict,
  athlete_id uuid not null
    references public.athletes (id) on delete cascade,
  numeric_value numeric(12, 4) not null,
  notes text not null default '',
  source text not null default 'coach'
    check (source in ('coach', 'athlete', 'import')),
  recorded_by uuid not null references auth.users (id) on delete restrict,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (session_id, metric_id)
);

create index testing_protocols_coach_status_idx
  on public.testing_protocols (coach_user_id, status, updated_at desc);
create index testing_protocols_parent_idx
  on public.testing_protocols (parent_protocol_id);
create index testing_metrics_protocol_sort_idx
  on public.testing_metrics (protocol_id, sort_order);
create index testing_sessions_athlete_schedule_idx
  on public.testing_sessions (athlete_id, scheduled_at desc);
create index testing_sessions_protocol_status_idx
  on public.testing_sessions (protocol_id, status);
create index testing_sessions_creator_idx
  on public.testing_sessions (created_by);
create index testing_results_athlete_metric_date_idx
  on public.testing_results (athlete_id, metric_id, recorded_at desc);
create index testing_results_session_idx
  on public.testing_results (session_id);
create index testing_results_recorded_by_idx
  on public.testing_results (recorded_by);

create trigger set_testing_protocols_updated_at
before update on public.testing_protocols
for each row execute function public.set_updated_at();

create trigger set_testing_metrics_updated_at
before update on public.testing_metrics
for each row execute function public.set_updated_at();

create trigger set_testing_sessions_updated_at
before update on public.testing_sessions
for each row execute function public.set_updated_at();

create trigger set_testing_results_updated_at
before update on public.testing_results
for each row execute function public.set_updated_at();

alter table public.testing_protocols enable row level security;
alter table public.testing_metrics enable row level security;
alter table public.testing_sessions enable row level security;
alter table public.testing_results enable row level security;

revoke all on public.testing_protocols from anon;
revoke all on public.testing_metrics from anon;
revoke all on public.testing_sessions from anon;
revoke all on public.testing_results from anon;
grant select, insert, update, delete on public.testing_protocols to authenticated;
grant select, insert, update, delete on public.testing_metrics to authenticated;
grant select, insert, update, delete on public.testing_sessions to authenticated;
grant select, insert, update on public.testing_results to authenticated;

create or replace function public.can_access_testing_session(
  check_session_id uuid,
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
    from public.testing_sessions session
    join public.testing_protocols protocol
      on protocol.id = session.protocol_id
    join public.athletes athlete on athlete.id = session.athlete_id
    where session.id = check_session_id
      and (
        athlete.user_id = check_user_id
        or (
          protocol.coach_user_id = check_user_id
          and public.coach_manages_athlete(
            session.athlete_id,
            check_user_id
          )
        )
      )
  );
$$;

revoke all on function public.can_access_testing_session(uuid, uuid)
  from public;
grant execute on function public.can_access_testing_session(uuid, uuid)
  to authenticated;

create policy "Coaches manage their testing protocols"
on public.testing_protocols
for all
to authenticated
using (coach_user_id = (select auth.uid()))
with check (coach_user_id = (select auth.uid()));

create policy "Athletes view assigned testing protocols"
on public.testing_protocols
for select
to authenticated
using (
  status = 'active'
  and exists (
    select 1
    from public.testing_sessions session
    join public.athletes athlete on athlete.id = session.athlete_id
    where session.protocol_id = testing_protocols.id
      and athlete.user_id = (select auth.uid())
  )
);

create policy "Coaches manage metrics in their protocols"
on public.testing_metrics
for all
to authenticated
using (
  exists (
    select 1 from public.testing_protocols protocol
    where protocol.id = protocol_id
      and protocol.coach_user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.testing_protocols protocol
    where protocol.id = protocol_id
      and protocol.coach_user_id = (select auth.uid())
  )
);

create policy "Athletes view metrics for assigned tests"
on public.testing_metrics
for select
to authenticated
using (
  exists (
    select 1
    from public.testing_sessions session
    join public.athletes athlete on athlete.id = session.athlete_id
    where session.protocol_id = testing_metrics.protocol_id
      and athlete.user_id = (select auth.uid())
  )
);

create policy "Coaches manage linked athlete testing sessions"
on public.testing_sessions
for all
to authenticated
using (
  exists (
    select 1 from public.testing_protocols protocol
    where protocol.id = protocol_id
      and protocol.coach_user_id = (select auth.uid())
  )
  and public.coach_manages_athlete(athlete_id, (select auth.uid()))
)
with check (
  exists (
    select 1 from public.testing_protocols protocol
    where protocol.id = protocol_id
      and protocol.coach_user_id = (select auth.uid())
      and protocol.status = 'active'
  )
  and created_by = (select auth.uid())
  and public.coach_manages_athlete(athlete_id, (select auth.uid()))
);

create policy "Athletes view their testing sessions"
on public.testing_sessions
for select
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
);

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
);

create policy "Coaches manage linked athlete testing results"
on public.testing_results
for all
to authenticated
using (
  public.can_access_testing_session(session_id, (select auth.uid()))
  and exists (
    select 1
    from public.testing_sessions session
    join public.testing_protocols protocol
      on protocol.id = session.protocol_id
    where session.id = session_id
      and protocol.coach_user_id = (select auth.uid())
  )
)
with check (
  recorded_by = (select auth.uid())
  and source = 'coach'
  and public.coach_manages_athlete(athlete_id, (select auth.uid()))
  and exists (
    select 1
    from public.testing_sessions session
    join public.testing_metrics metric
      on metric.protocol_id = session.protocol_id
    where session.id = session_id
      and session.athlete_id = athlete_id
      and metric.id = metric_id
  )
);

create policy "Athletes view their testing results"
on public.testing_results
for select
to authenticated
using (
  public.athlete_owns_profile(athlete_id, (select auth.uid()))
);

create policy "Athletes create allowed self testing results"
on public.testing_results
for insert
to authenticated
with check (
  recorded_by = (select auth.uid())
  and source = 'athlete'
  and public.athlete_owns_profile(athlete_id, (select auth.uid()))
  and exists (
    select 1
    from public.testing_sessions session
    join public.testing_protocols protocol
      on protocol.id = session.protocol_id
    join public.testing_metrics metric
      on metric.protocol_id = protocol.id
    where session.id = session_id
      and session.athlete_id = athlete_id
      and session.status in ('scheduled', 'in_progress')
      and protocol.status = 'active'
      and protocol.allows_athlete_entry
      and metric.id = metric_id
  )
);

create policy "Athletes update their self testing results"
on public.testing_results
for update
to authenticated
using (
  source = 'athlete'
  and recorded_by = (select auth.uid())
  and public.athlete_owns_profile(athlete_id, (select auth.uid()))
)
with check (
  source = 'athlete'
  and recorded_by = (select auth.uid())
  and public.athlete_owns_profile(athlete_id, (select auth.uid()))
  and exists (
    select 1
    from public.testing_sessions session
    join public.testing_protocols protocol
      on protocol.id = session.protocol_id
    join public.testing_metrics metric
      on metric.protocol_id = protocol.id
    where session.id = session_id
      and session.athlete_id = athlete_id
      and session.status in ('scheduled', 'in_progress')
      and protocol.status = 'active'
      and protocol.allows_athlete_entry
      and metric.id = metric_id
  )
);
