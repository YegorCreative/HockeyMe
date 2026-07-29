create table public.coaches (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.coaches enable row level security;

revoke all on table public.coaches from anon;
grant select on table public.coaches to authenticated;

create policy "Coaches can view their own coach record"
on public.coaches
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Coaches can view athlete profiles"
on public.athletes
for select
to authenticated
using (
  exists (
    select 1
    from public.coaches
    where coaches.user_id = (select auth.uid())
  )
);
