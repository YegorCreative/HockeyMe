create table public.athletes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  first_name text,
  last_name text,
  date_of_birth date,
  height_inches integer,
  weight_pounds integer,
  position text,
  team text,
  graduation_year integer,
  shoots text,
  training_goals text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.athletes enable row level security;

revoke all on table public.athletes from anon;
grant select, insert, update on table public.athletes to authenticated;

create policy "Athletes can insert their own profile"
on public.athletes
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Athletes can view their own profile"
on public.athletes
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Athletes can update their own profile"
on public.athletes
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create function public.set_athletes_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_athletes_updated_at
before update on public.athletes
for each row
execute function public.set_athletes_updated_at();
