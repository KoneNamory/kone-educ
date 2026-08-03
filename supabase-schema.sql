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
grant update on public.profiles to authenticated;
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);
create policy "Allow authenticated request inserts" on public.course_requests for insert to authenticated with check (auth.uid() = parent_id);
create policy "Parents read own requests" on public.course_requests for select to authenticated using (auth.uid() = parent_id);

create table if not exists public.teacher_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  degree text,
  subject text,
  experience text,
  availability text,
  location text,
  format text,
  bio text,
  approved boolean not null default false
);
alter table public.teacher_profiles enable row level security;
alter table public.teacher_profiles add column if not exists location text;
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

-- Attribution d'un enseignant par l'administrateur
alter table public.course_requests
  add column if not exists teacher_id uuid references public.profiles(id) on delete set null;

grant update on public.course_requests to authenticated;
drop policy if exists "Admins read all course requests" on public.course_requests;
drop policy if exists "Admins update course requests" on public.course_requests;
drop policy if exists "Teachers read assigned course requests" on public.course_requests;
create policy "Admins read all course requests" on public.course_requests
  for select to authenticated
  using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));
create policy "Admins update course requests" on public.course_requests
  for update to authenticated
  using (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'))
  with check (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));
create policy "Teachers read assigned course requests" on public.course_requests
  for select to authenticated
  using (teacher_id = auth.uid());

-- Notifications visibles dans les espaces Parent et Enseignant
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
grant select, insert, update on public.notifications to authenticated;
grant usage, select on sequence public.notifications_id_seq to authenticated;
drop policy if exists "Users read own notifications" on public.notifications;
drop policy if exists "Users mark own notifications read" on public.notifications;
drop policy if exists "Admins create notifications" on public.notifications;
create policy "Users read own notifications" on public.notifications
  for select to authenticated using (recipient_id = auth.uid());
create policy "Users mark own notifications read" on public.notifications
  for update to authenticated using (recipient_id = auth.uid());
create policy "Admins create notifications" on public.notifications
  for insert to authenticated
  with check (exists (select 1 from public.profiles where profiles.id = auth.uid() and profiles.role = 'admin'));

create table if not exists public.documents (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  audience text not null check (audience in ('parent','teacher','all')),
  storage_path text not null unique,
  file_name text not null,
  created_at timestamptz not null default now()
);
alter table public.documents enable row level security;
grant select, insert, delete on public.documents to authenticated;
grant usage, select on sequence public.documents_id_seq to authenticated;
create policy "Users read intended documents" on public.documents for select to authenticated using (audience='all' or audience=(select role from public.profiles where id=auth.uid()) or exists(select 1 from public.profiles where id=auth.uid() and role='admin'));
create policy "Admins manage documents" on public.documents for all to authenticated using (exists(select 1 from public.profiles where id=auth.uid() and role='admin')) with check (exists(select 1 from public.profiles where id=auth.uid() and role='admin'));

-- Messagerie entre le parent et l'enseignant attribué à une demande de cours
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);
alter table public.messages enable row level security;
grant select, insert on public.messages to authenticated;
grant usage, select on sequence public.messages_id_seq to authenticated;
drop policy if exists "Participants read own messages" on public.messages;
drop policy if exists "Participants send messages on their course" on public.messages;
create policy "Participants read own messages" on public.messages
  for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy "Participants send messages on their course" on public.messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.course_requests cr
      where cr.id = course_request_id
        and cr.parent_id is not null and cr.teacher_id is not null
        and (cr.parent_id = auth.uid() or cr.teacher_id = auth.uid())
        and (recipient_id = cr.parent_id or recipient_id = cr.teacher_id)
        and recipient_id <> auth.uid()
    )
  );
