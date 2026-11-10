-- BerberOS database schema. Run this entire file in Supabase SQL Editor.
create extension if not exists pgcrypto;
create type public.app_role as enum ('owner','staff');
create type public.appointment_status as enum ('booked','completed','cancelled','no_show');
create type public.payment_status as enum ('unpaid','partial','paid');

create table public.businesses (
 id uuid primary key default gen_random_uuid(), name text not null default 'BerberOS', owner_id uuid not null references auth.users(id) on delete restrict,
 split_percent numeric(5,2) not null default 50 check(split_percent between 0 and 100), created_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 business_id uuid not null references public.businesses(id) on delete cascade,
 full_name text not null, role public.app_role not null default 'staff', active boolean not null default true,
 created_at timestamptz not null default now()
);
create table public.customers (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 full_name text not null, phone text, notes text, created_at timestamptz not null default now()
);
create table public.appointments (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 staff_id uuid not null references public.profiles(id), customer_id uuid references public.customers(id) on delete set null,
 customer_name text not null, customer_phone text, service_name text not null default 'Saç kesimi', starts_at timestamptz not null,
 status public.appointment_status not null default 'booked', notes text, created_at timestamptz not null default now()
);
create table public.services (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 name text not null, active boolean not null default true, created_at timestamptz not null default now()
);
create table public.transactions (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 staff_id uuid not null references public.profiles(id), customer_id uuid references public.customers(id) on delete set null,
 customer_name text not null, service_name text not null, amount numeric(12,2) not null check(amount >= 0),
 employee_percent numeric(5,2) not null default 50 check(employee_percent between 0 and 100),
 payment_status public.payment_status not null default 'paid', paid_amount numeric(12,2) not null default 0 check(paid_amount >= 0),
 payment_method text not null default 'cash', performed_at timestamptz not null default now(), notes text, created_at timestamptz not null default now()
);
create table public.cash_entries (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 created_by uuid not null references public.profiles(id), kind text not null check(kind in ('expense','income','collection','refund')),
 amount numeric(12,2) not null check(amount > 0), description text not null, created_at timestamptz not null default now()
);
create table public.audit_log (
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id) on delete cascade,
 actor_id uuid references public.profiles(id), action text not null, entity text not null, entity_id uuid, details jsonb not null default '{}', created_at timestamptz not null default now()
);

create or replace function public.current_business_id() returns uuid language sql stable security definer set search_path=public as $$ select business_id from public.profiles where id=auth.uid() and active=true limit 1 $$;
create or replace function public.is_owner() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='owner' and active=true) $$;
create or replace function public.can_access_staff(target uuid) returns boolean language sql stable security definer set search_path=public as $$ select target=auth.uid() or public.is_owner() $$;

alter table public.businesses enable row level security;
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.appointments enable row level security;
alter table public.services enable row level security;
alter table public.transactions enable row level security;
alter table public.cash_entries enable row level security;
alter table public.audit_log enable row level security;

create policy "business visible to members" on public.businesses for select using(id=public.current_business_id());
create policy "owner updates business" on public.businesses for update using(public.is_owner() and id=public.current_business_id()) with check(public.is_owner() and id=public.current_business_id());
create policy "profiles visible to self and owner" on public.profiles for select using(business_id=public.current_business_id() and (id=auth.uid() or public.is_owner()));
create policy "owner manages profiles" on public.profiles for all using(public.is_owner() and business_id=public.current_business_id()) with check(public.is_owner() and business_id=public.current_business_id());
create policy "customers member scope" on public.customers for all using(business_id=public.current_business_id()) with check(business_id=public.current_business_id());
create policy "appointments own or owner" on public.appointments for select using(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "appointments insert own or owner" on public.appointments for insert with check(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "appointments update own or owner" on public.appointments for update using(business_id=public.current_business_id() and public.can_access_staff(staff_id)) with check(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "appointments delete own or owner" on public.appointments for delete using(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "services member read" on public.services for select using(business_id=public.current_business_id());
create policy "services owner manage" on public.services for all using(public.is_owner() and business_id=public.current_business_id()) with check(public.is_owner() and business_id=public.current_business_id());
create policy "transactions own or owner select" on public.transactions for select using(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "transactions own or owner insert" on public.transactions for insert with check(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "transactions own or owner update" on public.transactions for update using(business_id=public.current_business_id() and public.can_access_staff(staff_id)) with check(business_id=public.current_business_id() and public.can_access_staff(staff_id));
create policy "transactions owner delete" on public.transactions for delete using(public.is_owner() and business_id=public.current_business_id());
create policy "cash owner all staff read own" on public.cash_entries for select using(business_id=public.current_business_id() and (public.is_owner() or created_by=auth.uid()));
create policy "cash insert own" on public.cash_entries for insert with check(business_id=public.current_business_id() and created_by=auth.uid());
create policy "cash owner manage" on public.cash_entries for all using(public.is_owner() and business_id=public.current_business_id()) with check(public.is_owner() and business_id=public.current_business_id());
create policy "audit owner read" on public.audit_log for select using(business_id=public.current_business_id() and public.is_owner());
create policy "audit member insert" on public.audit_log for insert with check(business_id=public.current_business_id() and actor_id=auth.uid());

-- IMPORTANT: create the owner auth user first in Supabase Authentication, then replace the UUID below and run this bootstrap block.
-- insert into businesses(name, owner_id) values ('Ergün Erkek Kuaförü', 'OWNER_AUTH_USER_UUID') returning id;
-- insert into profiles(id,business_id,full_name,role) values ('OWNER_AUTH_USER_UUID','BUSINESS_UUID','Ergün','owner');
