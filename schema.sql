-- RideBarkada MVP schema
create extension if not exists pgcrypto;

create type public.user_role as enum ('passenger','rider','admin');
create type public.ride_status as enum ('requested','accepted','arriving','ongoing','completed','cancelled');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'New User',
  phone text,
  role public.user_role not null default 'passenger',
  is_online boolean not null default false,
  motorcycle_model text,
  plate_number text,
  created_at timestamptz not null default now()
);

create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(),
  passenger_id uuid not null references public.profiles(id),
  rider_id uuid references public.profiles(id),
  pickup_address text not null,
  destination_address text not null,
  distance_km numeric(8,2) not null default 0,
  estimated_fare numeric(10,2) not null default 50,
  status public.ride_status not null default 'requested',
  accepted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid unique not null references public.rides(id) on delete cascade,
  passenger_id uuid not null references public.profiles(id),
  rider_id uuid not null references public.profiles(id),
  stars int not null check(stars between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','New User'))
  on conflict(id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.rides enable row level security;
alter table public.ratings enable row level security;

create policy "profiles readable by authenticated users" on public.profiles
for select to authenticated using (true);

create policy "users update own profile" on public.profiles
for update to authenticated using (id=auth.uid()) with check (id=auth.uid());

create policy "users insert own profile" on public.profiles
for insert to authenticated with check (id=auth.uid());

create policy "passengers create rides" on public.rides
for insert to authenticated with check (passenger_id=auth.uid());

create policy "users view relevant rides" on public.rides
for select to authenticated using (
  passenger_id=auth.uid() or rider_id=auth.uid()
  or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin')
  or (status='requested' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='rider' and p.is_online=true))
);

create policy "riders/admin update rides" on public.rides
for update to authenticated using (
  rider_id=auth.uid()
  or (status='requested' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='rider' and p.is_online=true))
  or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin')
) with check (
  rider_id=auth.uid()
  or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin')
);

create policy "rating insert by passenger" on public.ratings
for insert to authenticated with check (passenger_id=auth.uid());

create policy "ratings readable" on public.ratings
for select to authenticated using (true);

-- After creating your own admin/rider accounts, assign roles manually:
-- update public.profiles set role='admin' where id='YOUR-USER-UUID';
-- update public.profiles set role='rider', motorcycle_model='Honda Click', plate_number='ABC1234' where id='RIDER-USER-UUID';

-- Enable realtime for ride status changes.
alter publication supabase_realtime add table public.rides;
