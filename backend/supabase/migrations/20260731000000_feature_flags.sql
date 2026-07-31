create table public.feature_flags (
  id uuid primary key default gen_random_uuid(),
  key text not null unique
    check (key ~ '^[a-z0-9]+(?:_[a-z0-9]+)*$'),
  enabled boolean not null default false,
  environments text[] not null default array['debug']::text[]
    check (
      cardinality(environments) > 0
      and environments <@ array['debug', 'staging', 'production']::text[]
    ),
  audience text not null default 'all'
    check (audience in ('all', 'internal', 'beta')),
  rollout_percentage integer not null default 0
    check (rollout_percentage between 0 and 100),
  minimum_version text,
  payload jsonb not null default '{}'::jsonb,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index feature_flags_environment_idx
  on public.feature_flags using gin (environments)
  where deleted_at is null;

create trigger set_feature_flags_updated_at
before update on public.feature_flags
for each row execute function public.set_updated_at();

alter table public.feature_flags enable row level security;
revoke all on public.feature_flags from anon, authenticated;
grant select on public.feature_flags to anon, authenticated;

create policy "Clients read non-secret feature configuration"
on public.feature_flags for select to anon, authenticated using (
  deleted_at is null
);

comment on table public.feature_flags is
  'Non-secret rollout configuration. Never store credentials or personal data.';
