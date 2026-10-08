create extension if not exists pgcrypto;
do $$ begin create type public.user_role as enum ('passenger','rider','admin'); exception when duplicate_object then null; end $$;
do $$ begin create type public.ride_status as enum ('requested','accepted','arriving','ongoing','completed','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.rental_status as enum ('requested','confirmed','picked_up','returned','cancelled'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text default 'New User',phone text,role public.user_role default 'passenger',is_online boolean default false,motorcycle_model text,plate_number text,created_at timestamptz default now());
create table if not exists public.rides(id uuid primary key default gen_random_uuid(),passenger_id uuid references public.profiles(id) on delete set null,rider_id uuid references public.profiles(id) on delete set null,pickup_address text not null,destination_address text not null,distance_km numeric(10,2),estimated_fare numeric(10,2) not null default 50,status public.ride_status default 'requested',accepted_at timestamptz,completed_at timestamptz,created_at timestamptz default now());
create table if not exists public.motorcycles(id text primary key,name text not null,model text,plate_number text,transmission text,rental_rate_day numeric(10,2) not null,security_deposit numeric(10,2) default 0,available boolean default true,created_at timestamptz default now());
create table if not exists public.rental_bookings(id uuid primary key default gen_random_uuid(),customer_id uuid references public.profiles(id) on delete set null,motorcycle_id text references public.motorcycles(id) on delete set null,pickup_location text,rental_start timestamptz,rental_end timestamptz,duration_days integer default 1,rental_fee numeric(10,2) not null,security_deposit numeric(10,2) default 0,status public.rental_status default 'requested',created_at timestamptz default now());
create table if not exists public.ratings(id uuid primary key default gen_random_uuid(),ride_id uuid references public.rides(id) on delete cascade,passenger_id uuid references public.profiles(id) on delete set null,rider_id uuid references public.profiles(id) on delete set null,stars integer check(stars between 1 and 5),comment text,created_at timestamptz default now());

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name,phone) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','New User'),new.raw_user_meta_data->>'phone') on conflict(id) do nothing; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users; create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security; alter table public.rides enable row level security; alter table public.motorcycles enable row level security; alter table public.rental_bookings enable row level security; alter table public.ratings enable row level security;
drop policy if exists profiles_self on public.profiles; create policy profiles_self on public.profiles for select using(auth.uid()=id);
drop policy if exists rider_discovery on public.profiles; create policy rider_discovery on public.profiles for select using(role='rider' and is_online=true);
drop policy if exists profiles_update on public.profiles; create policy profiles_update on public.profiles for update using(auth.uid()=id);
drop policy if exists ride_insert on public.rides; create policy ride_insert on public.rides for insert with check(auth.uid()=passenger_id);
drop policy if exists ride_read on public.rides; create policy ride_read on public.rides for select using(auth.uid()=passenger_id or auth.uid()=rider_id);
drop policy if exists ride_update on public.rides; create policy ride_update on public.rides for update using(auth.uid()=passenger_id or auth.uid()=rider_id);
drop policy if exists bikes_read on public.motorcycles; create policy bikes_read on public.motorcycles for select to authenticated using(available=true);
drop policy if exists rental_insert on public.rental_bookings; create policy rental_insert on public.rental_bookings for insert with check(auth.uid()=customer_id);
drop policy if exists rental_read on public.rental_bookings; create policy rental_read on public.rental_bookings for select using(auth.uid()=customer_id);

insert into public.motorcycles(id,name,model,transmission,rental_rate_day,security_deposit) values
('bike-001','Honda Click 125','Click 125','Automatic',350,1000),
('bike-002','Yamaha Mio Sporty','Mio Sporty','Automatic',300,1000),
('bike-003','Honda Beat','Beat','Automatic',320,1000) on conflict(id) do nothing;

-- Optional realtime for live ride status:
-- alter publication supabase_realtime add table public.rides;
