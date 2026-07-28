-- KONE.EDUC - schéma et droits Supabase
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('parent','teacher','admin')),
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.course_requests (
  id bigint generated always as identity primary key,
  parent_id uuid references public.profiles(id) on delete set null,
  student_name text not null,
  school_level text not null,
  subject text not null,
  location text not null,
  format text not null,
  availability text not null,
  details text,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.course_requests enable row level security;

grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
grant insert, select on public.course_requests to authenticated;
grant usage, select on sequence public.course_requests_id_seq to authenticated;

drop policy if exists "Users create own profile" on public.profiles;
drop policy if exists "Users read own profile" on public.profiles;
drop policy if exists "Allow authenticated request inserts" on public.course_requests;
drop policy if exists "Parents read own requests" on public.course_requests;

create policy "Users create own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "Users read own profile" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "Allow authenticated request inserts" on public.course_requests for insert to authenticated with check (auth.uid() = parent_id);
create policy "Parents read own requests" on public.course_requests for select to authenticated using (auth.uid() = parent_id);

create table if not exists public.teacher_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  degree text,
  subject text,
  experience text,
  availability text,
  format text,
  bio text,
  approved boolean not null default false
);
alter table public.teacher_profiles enable row level security;
grant insert, select on public.teacher_profiles to authenticated;
drop policy if exists "Teachers create own profile" on public.teacher_profiles;
create policy "Teachers create own profile" on public.teacher_profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Teachers read own profile" on public.teacher_profiles;
drop policy if exists "Teachers update own profile" on public.teacher_profiles;
create policy "Teachers read own profile" on public.teacher_profiles for select to authenticated using (auth.uid() = id);
create policy "Teachers update own profile" on public.teacher_profiles for update to authenticated using (auth.uid() = id);

grant update on public.teacher_profiles to authenticated;
drop policy if exists "Admins read teacher profiles" on public.teacher_profiles;
drop policy if exists "Admins update teacher profiles" on public.teacher_profiles;
create policy "Admins read teacher profiles" on public.teacher_profiles for select to authenticated using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));
create policy "Admins update teacher profiles" on public.teacher_profiles for update to authenticated using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));
