-- KONE.EDUC - schéma initial Supabase
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('parent', 'teacher', 'admin')),
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
  status text not null default 'pending' check (status in ('pending', 'assigned', 'completed', 'cancelled')),
  created_at timestamptz not null default now()
);

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

alter table public.profiles enable row level security;
alter table public.course_requests enable row level security;
alter table public.teacher_profiles enable row level security;

create policy "Users read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Parents create requests" on public.course_requests for insert with check (auth.uid() = parent_id);
create policy "Parents read own requests" on public.course_requests for select using (auth.uid() = parent_id);
create policy "Teachers update own profile" on public.teacher_profiles for update using (auth.uid() = id);
create policy "Teachers read own profile" on public.teacher_profiles for select using (auth.uid() = id);
