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
-- Droit explicite de créer son propre profil (la règle ci-dessous limite aux rôles Parent et Enseignant)
grant insert on public.profiles to authenticated;
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
drop policy if exists "Users read intended documents" on public.documents;
drop policy if exists "Admins manage documents" on public.documents;
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

-- Sécurité : empêcher un utilisateur de se donner des droits qu'il n'a pas
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- À l'inscription, seuls les rôles Parent, Enseignant et Vendeur peuvent être choisis
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('parent','teacher','admin','seller'));
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles for insert to authenticated
  with check (auth.uid() = id and role in ('parent','teacher','seller'));

-- Le rôle ne peut être modifié que par un administrateur (ou depuis le tableau de bord Supabase)
create or replace function public.protect_profile_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role and auth.uid() is not null and not public.is_admin() then
    raise exception 'Modification du rôle non autorisée';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role before update on public.profiles
  for each row execute function public.protect_profile_role();

-- Un enseignant ne peut pas valider sa propre candidature
-- Seul un compte de type Enseignant peut déposer ou modifier une candidature
drop policy if exists "Teachers create own profile" on public.teacher_profiles;
create policy "Teachers create own profile" on public.teacher_profiles for insert to authenticated
  with check (auth.uid() = id and approved = false
              and exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher'));
drop policy if exists "Teachers update own profile" on public.teacher_profiles;
create policy "Teachers update own profile" on public.teacher_profiles for update to authenticated
  using (auth.uid() = id and exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher'));
create or replace function public.protect_teacher_approval() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.approved is distinct from old.approved and auth.uid() is not null and not public.is_admin() then
    raise exception 'Seul un administrateur peut valider une candidature';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_teacher_approval on public.teacher_profiles;
create trigger protect_teacher_approval before update on public.teacher_profiles
  for each row execute function public.protect_teacher_approval();

-- Une nouvelle demande de cours est toujours en attente et sans enseignant
drop policy if exists "Allow authenticated request inserts" on public.course_requests;
create policy "Allow authenticated request inserts" on public.course_requests for insert to authenticated
  with check (auth.uid() = parent_id and teacher_id is null and status = 'pending'
              and exists (select 1 from public.profiles where id = auth.uid() and role = 'parent'));

-- Notification automatique du destinataire à chaque nouveau message
create or replace function public.notify_new_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body)
  select new.recipient_id, 'Nouveau message',
         'Nouveau message concernant le cours de ' || cr.subject || ' pour ' || cr.student_name || '.'
  from public.course_requests cr where cr.id = new.course_request_id;
  return new;
end;
$$;
drop trigger if exists notify_new_message on public.messages;
create trigger notify_new_message after insert on public.messages
  for each row execute function public.notify_new_message();

-- Messages envoyés depuis le formulaire de contact (visiteurs connectés ou non)
create table if not exists public.contact_messages (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) <= 120),
  email text not null check (char_length(email) <= 200),
  subject text not null check (char_length(subject) <= 100),
  message text not null check (char_length(message) <= 3000),
  created_at timestamptz not null default now()
);
alter table public.contact_messages enable row level security;
grant insert on public.contact_messages to anon, authenticated;
grant select, delete on public.contact_messages to authenticated;
drop policy if exists "Anyone sends a contact message" on public.contact_messages;
drop policy if exists "Admins read contact messages" on public.contact_messages;
drop policy if exists "Admins delete contact messages" on public.contact_messages;
create policy "Anyone sends a contact message" on public.contact_messages for insert to anon, authenticated with check (true);
create policy "Admins read contact messages" on public.contact_messages for select to authenticated using (public.is_admin());
create policy "Admins delete contact messages" on public.contact_messages for delete to authenticated using (public.is_admin());

-- Factures mensuelles et paiements (Wave Business, Orange Money)
create table if not exists public.invoices (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  month date not null,
  amount integer not null check (amount > 0),
  status text not null default 'unpaid' check (status in ('unpaid','pending','paid')),
  payment_method text check (payment_method in ('wave','orange_money')),
  payment_reference text check (char_length(payment_reference) <= 100),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (course_request_id, month)
);
alter table public.invoices enable row level security;
grant select, update on public.invoices to authenticated;
grant insert, delete on public.invoices to authenticated;
grant usage, select on sequence public.invoices_id_seq to authenticated;
drop policy if exists "Parents read own invoices" on public.invoices;
drop policy if exists "Parents declare payment" on public.invoices;
drop policy if exists "Admins manage invoices" on public.invoices;
create policy "Parents read own invoices" on public.invoices for select to authenticated using (parent_id = auth.uid());
create policy "Parents declare payment" on public.invoices for update to authenticated
  using (parent_id = auth.uid() and status <> 'paid') with check (parent_id = auth.uid());
create policy "Admins manage invoices" on public.invoices for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Un parent peut seulement déclarer son paiement (moyen + référence) ; seul un administrateur confirme
create or replace function public.protect_invoice() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.is_admin() then
    if new.status = 'paid' and old.status <> 'paid' then new.paid_at := now(); end if;
    return new;
  end if;
  if new.course_request_id <> old.course_request_id or new.parent_id <> old.parent_id
     or new.month <> old.month or new.amount <> old.amount or new.paid_at is distinct from old.paid_at
     or new.due_date is distinct from old.due_date
     or new.status <> 'pending' or new.payment_method is null or coalesce(trim(new.payment_reference),'') = '' then
    raise exception 'Seuls le moyen de paiement et la référence de transaction peuvent être indiqués';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_invoice on public.invoices;
create trigger protect_invoice before update on public.invoices
  for each row execute function public.protect_invoice();

-- Notifications liées aux factures
create or replace function public.notify_invoice() returns trigger
language plpgsql security definer set search_path = public as $$
declare label text;
begin
  label := to_char(new.month, 'MM/YYYY') || ' · ' || new.amount || ' FCFA';
  if tg_op = 'INSERT' then
    insert into public.notifications (recipient_id, title, body)
    values (new.parent_id, 'Nouvelle facture', 'Votre facture de ' || label || ' est disponible dans « Mes paiements ».');
  elsif new.status = 'pending' and old.status <> 'pending' then
    insert into public.notifications (recipient_id, title, body)
    select id, 'Paiement à vérifier', 'Paiement déclaré pour la facture de ' || label || ' (réf. ' || new.payment_reference || ').'
    from public.profiles where role = 'admin';
  elsif new.status = 'paid' and old.status <> 'paid' then
    insert into public.notifications (recipient_id, title, body)
    values (new.parent_id, 'Paiement confirmé', 'Merci ! Votre paiement de ' || label || ' a été confirmé.');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_invoice on public.invoices;
create trigger notify_invoice after insert or update on public.invoices
  for each row execute function public.notify_invoice();

-- Suivi pédagogique : compte rendu de l'enseignant après chaque séance
create table if not exists public.session_reports (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  session_date date not null,
  duration_minutes integer not null check (duration_minutes between 15 and 480),
  topics text not null check (char_length(topics) <= 500),
  understanding smallint not null check (understanding between 1 and 5),
  homework text check (char_length(homework) <= 500),
  comment text check (char_length(comment) <= 1500),
  created_at timestamptz not null default now()
);
alter table public.session_reports enable row level security;
grant select, insert on public.session_reports to authenticated;
grant usage, select on sequence public.session_reports_id_seq to authenticated;
drop policy if exists "Teachers write reports for assigned courses" on public.session_reports;
drop policy if exists "Course participants read reports" on public.session_reports;
create policy "Teachers write reports for assigned courses" on public.session_reports for insert to authenticated
  with check (teacher_id = auth.uid() and exists (select 1 from public.course_requests cr where cr.id = course_request_id and cr.teacher_id = auth.uid()));
create policy "Course participants read reports" on public.session_reports for select to authenticated
  using (teacher_id = auth.uid() or public.is_admin()
         or exists (select 1 from public.course_requests cr where cr.id = course_request_id and cr.parent_id = auth.uid()));

create or replace function public.notify_session_report() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body)
  select cr.parent_id, 'Nouveau compte rendu',
         'Séance de ' || cr.subject || ' du ' || to_char(new.session_date, 'DD/MM/YYYY') || ' pour ' || cr.student_name || ' : ' || new.topics
  from public.course_requests cr where cr.id = new.course_request_id and cr.parent_id is not null;
  return new;
end;
$$;
drop trigger if exists notify_session_report on public.session_reports;
create trigger notify_session_report after insert on public.session_reports
  for each row execute function public.notify_session_report();

-- Avis des parents sur l'enseignant attribué (un avis par cours, modifiable)
create table if not exists public.reviews (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  created_at timestamptz not null default now(),
  unique (course_request_id, parent_id)
);
alter table public.reviews enable row level security;
grant select, insert, update on public.reviews to authenticated;
grant usage, select on sequence public.reviews_id_seq to authenticated;
drop policy if exists "Parents review their course teacher" on public.reviews;
drop policy if exists "Parents update own review" on public.reviews;
drop policy if exists "Review participants read reviews" on public.reviews;
create policy "Parents review their course teacher" on public.reviews for insert to authenticated
  with check (parent_id = auth.uid() and exists (select 1 from public.course_requests cr
    where cr.id = course_request_id and cr.parent_id = auth.uid() and cr.teacher_id = reviews.teacher_id));
create policy "Parents update own review" on public.reviews for update to authenticated
  using (parent_id = auth.uid())
  with check (parent_id = auth.uid() and exists (select 1 from public.course_requests cr
    where cr.id = course_request_id and cr.parent_id = auth.uid() and cr.teacher_id = reviews.teacher_id));
create policy "Review participants read reviews" on public.reviews for select to authenticated
  using (parent_id = auth.uid() or teacher_id = auth.uid() or public.is_admin());

-- Moov Money comme moyen de paiement supplémentaire
alter table public.invoices drop constraint if exists invoices_payment_method_check;
alter table public.invoices add constraint invoices_payment_method_check
  check (payment_method in ('wave','orange_money','mtn_money','moov_money')) not valid;

-- L'administrateur voit le nom et le téléphone des parents et des enseignants pour les contacter
-- L'administrateur peut corriger un profil (ex. compte enseignant enregistré par erreur comme parent)
drop policy if exists "Admins update profiles" on public.profiles;
create policy "Admins update profiles" on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Admins read all profiles" on public.profiles;
create policy "Admins read all profiles" on public.profiles for select to authenticated using (public.is_admin());

-- Cycle de vie d'une demande : en attente → enseignant attribué → terminé, ou annulé
alter table public.course_requests drop constraint if exists course_requests_status_check;
alter table public.course_requests add constraint course_requests_status_check
  check (status in ('pending','assigned','completed','cancelled')) not valid;

-- Un parent peut seulement annuler sa propre demande tant qu'elle est en attente
drop policy if exists "Parents cancel own pending requests" on public.course_requests;
create policy "Parents cancel own pending requests" on public.course_requests for update to authenticated
  using (parent_id = auth.uid() and status = 'pending')
  with check (parent_id = auth.uid() and status = 'cancelled');
create or replace function public.protect_course_request() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.is_admin() then return new; end if;
  if old.status <> 'pending' or new.status <> 'cancelled'
     or (to_jsonb(new) - 'status') <> (to_jsonb(old) - 'status') then
    raise exception 'Seule l’annulation d’une demande en attente est possible';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_course_request on public.course_requests;
create trigger protect_course_request before update on public.course_requests
  for each row execute function public.protect_course_request();

-- Notifications quand une demande est terminée ou annulée
create or replace function public.notify_course_status() returns trigger
language plpgsql security definer set search_path = public as $$
declare label text;
begin
  if new.status = old.status or new.status not in ('completed','cancelled') then return new; end if;
  label := new.subject || ' pour ' || new.student_name;
  if new.status = 'completed' then
    insert into public.notifications (recipient_id, title, body)
    select x, 'Accompagnement terminé', 'L’accompagnement de ' || label || ' est terminé. Merci pour votre confiance !'
    from unnest(array[new.parent_id, new.teacher_id]) as x where x is not null;
  else
    insert into public.notifications (recipient_id, title, body)
    select x, 'Demande annulée', 'La demande de cours de ' || label || ' a été annulée.'
    from unnest(array[new.parent_id, new.teacher_id]) as x where x is not null;
  end if;
  return new;
end;
$$;
drop trigger if exists notify_course_status on public.course_requests;
create trigger notify_course_status after update on public.course_requests
  for each row execute function public.notify_course_status();

-- Niveaux enseignés indiqués dans la candidature (Primaire, Collège, Lycée, Université)
alter table public.teacher_profiles add column if not exists levels text;

-- Dossier de l'enseignant : photo de profil (publique) et documents justificatifs (privés)
alter table public.teacher_profiles add column if not exists photo_url text;
alter table public.teacher_profiles add column if not exists id_doc_path text;
alter table public.teacher_profiles add column if not exists diploma_path text;
alter table public.teacher_profiles add column if not exists cv_path text;

-- Espaces de stockage : « avatars » est public (photos de profil), « teacher-files » est privé (pièce d'identité, diplôme, CV)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('teacher-files', 'teacher-files', false, 5242880, array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Chaque utilisateur dépose ses fichiers uniquement dans son propre dossier (nommé par son identifiant)
drop policy if exists "Users upload own avatar" on storage.objects;
drop policy if exists "Users update own avatar" on storage.objects;
drop policy if exists "Users delete own avatar" on storage.objects;
drop policy if exists "Teachers upload own files" on storage.objects;
drop policy if exists "Teachers read own files" on storage.objects;
drop policy if exists "Teachers update own files" on storage.objects;
drop policy if exists "Users read own avatar" on storage.objects;
drop policy if exists "Admins read teacher files" on storage.objects;
create policy "Users upload own avatar" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users update own avatar" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users delete own avatar" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Teachers upload own files" on storage.objects for insert to authenticated
  with check (bucket_id = 'teacher-files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Teachers read own files" on storage.objects for select to authenticated
  using (bucket_id = 'teacher-files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Teachers update own files" on storage.objects for update to authenticated
  using (bucket_id = 'teacher-files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Users read own avatar" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Admins read teacher files" on storage.objects for select to authenticated
  using (bucket_id = 'teacher-files' and public.is_admin());

-- Profils publics : uniquement les enseignants validés, avec des informations non sensibles
-- (prénom et initiale du nom, matière, diplôme, niveaux, zone, présentation, photo, note moyenne)
create or replace function public.public_teachers()
returns table (id uuid, display_name text, subject text, degree text, experience text, levels text,
               location text, bio text, photo_url text, rating numeric, reviews_count bigint)
language sql stable security definer set search_path = public as $$
  select tp.id,
         split_part(n.nm, ' ', 1) ||
           case when position(' ' in n.nm) > 0 then ' ' || upper(left(split_part(n.nm, ' ', 2), 1)) || '.' else '' end,
         tp.subject, tp.degree, tp.experience, tp.levels, tp.location, tp.bio, tp.photo_url,
         round(avg(r.rating)::numeric, 1), count(r.id)
  from public.teacher_profiles tp
  join public.profiles p on p.id = tp.id
  cross join lateral (select regexp_replace(trim(p.full_name), '\s+', ' ', 'g') as nm) n
  left join public.reviews r on r.teacher_id = tp.id
  where tp.approved
  group by tp.id, n.nm
  order by count(r.id) desc, n.nm;
$$;
grant execute on function public.public_teachers() to anon, authenticated;

-- Inscription directe : le compte est créé déjà confirmé, sans e-mail de confirmation
-- (le site se connecte ensuite avec l’e-mail et le mot de passe)
create or replace function public.create_account(p_email text, p_password text, p_full_name text, p_phone text, p_role text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid := gen_random_uuid();
  v_email text := lower(trim(p_email));
begin
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Adresse e-mail invalide'; end if;
  if length(coalesce(p_password, '')) < 6 then raise exception 'Le mot de passe doit contenir au moins 6 caractères'; end if;
  if p_role not in ('parent', 'teacher', 'seller') then raise exception 'Type de compte invalide'; end if;
  if length(trim(coalesce(p_full_name, ''))) < 2 or length(p_full_name) > 120 then raise exception 'Nom invalide'; end if;
  if length(trim(coalesce(p_phone, ''))) < 8 or length(p_phone) > 30 then raise exception 'Numéro de téléphone invalide'; end if;
  if exists (select 1 from auth.users where lower(email) = v_email) then
    raise exception 'Un compte existe déjà avec cette adresse e-mail. Connectez-vous.';
  end if;
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current,
    phone_change, phone_change_token, reauthentication_token)
  values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', trim(p_full_name)), now(), now(),
    '', '', '', '', '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_id, v_id::text,
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true), 'email', now(), now(), now());
  insert into public.profiles (id, full_name, phone, role) values (v_id, trim(p_full_name), trim(p_phone), p_role);
  return v_id;
end;
$$;
revoke execute on function public.create_account(text, text, text, text, text) from public;
grant execute on function public.create_account(text, text, text, text, text) to anon, authenticated;

-- ============================================================
-- Offres de cours : les enseignants validés postulent aux demandes en attente
-- ============================================================
create table if not exists public.course_applications (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  message text check (char_length(message) <= 500),
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  unique (course_request_id, teacher_id)
);
alter table public.course_applications enable row level security;
grant select, insert, delete on public.course_applications to authenticated;
grant usage, select on sequence public.course_applications_id_seq to authenticated;

create or replace function public.is_approved_teacher() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.teacher_profiles tp join public.profiles p on p.id = tp.id
                 where tp.id = auth.uid() and tp.approved and p.role = 'teacher');
$$;
create or replace function public.is_open_request(p_id bigint) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.course_requests where id = p_id and status = 'pending' and teacher_id is null);
$$;

drop policy if exists "Teachers apply to open requests" on public.course_applications;
create policy "Teachers apply to open requests" on public.course_applications for insert to authenticated
  with check (teacher_id = auth.uid() and status = 'pending' and public.is_approved_teacher() and public.is_open_request(course_request_id));
drop policy if exists "Teachers and admins read applications" on public.course_applications;
create policy "Teachers and admins read applications" on public.course_applications for select to authenticated
  using (teacher_id = auth.uid() or public.is_admin());
drop policy if exists "Teachers withdraw pending applications" on public.course_applications;
create policy "Teachers withdraw pending applications" on public.course_applications for delete to authenticated
  using (teacher_id = auth.uid() and status = 'pending');

-- Offres visibles par un enseignant validé : demandes en attente (sans le nom de l'élève ni les précisions)
-- et demandes auxquelles il a déjà postulé, avec l'état de sa candidature
drop function if exists public.teacher_offers(); -- (redéfinie plus bas avec la préparation)
create function public.teacher_offers()
returns table (id bigint, subject text, school_level text, location text, format text, availability text,
               created_at timestamptz, request_status text, applicants bigint, my_status text, my_message text)
language sql stable security definer set search_path = public as $$
  select r.id, r.subject, r.school_level, r.location, r.format, r.availability, r.created_at, r.status,
         (select count(*) from public.course_applications a where a.course_request_id = r.id),
         mine.status, mine.message
  from public.course_requests r
  left join public.course_applications mine on mine.course_request_id = r.id and mine.teacher_id = auth.uid()
  where public.is_approved_teacher()
    and ((r.status = 'pending' and r.teacher_id is null) or mine.id is not null)
  order by r.created_at desc;
$$;
revoke execute on function public.teacher_offers() from public;
grant execute on function public.teacher_offers() to authenticated;

-- Nouvelle demande : les enseignants validés de la même matière sont prévenus
create or replace function public.notify_new_offer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body)
  select tp.id, 'Nouvelle offre de cours', new.subject || ' · ' || new.school_level || ' · ' || new.location || '. Postulez depuis « Offres de cours ».'
  from public.teacher_profiles tp join public.profiles p on p.id = tp.id
  where tp.approved and p.role = 'teacher' and lower(trim(tp.subject)) = lower(trim(new.subject));
  return new;
end;
$$;
drop trigger if exists notify_new_offer on public.course_requests;
create trigger notify_new_offer after insert on public.course_requests
  for each row execute function public.notify_new_offer();

-- Attribution : la candidature choisie est retenue, les autres sont refusées (avec notification)
create or replace function public.close_applications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.teacher_id is null or new.teacher_id is not distinct from old.teacher_id then return new; end if;
  with closed as (
    update public.course_applications set status = case when teacher_id = new.teacher_id then 'accepted' else 'rejected' end
    where course_request_id = new.id and status = 'pending'
    returning teacher_id, status)
  insert into public.notifications (recipient_id, title, body)
  select c.teacher_id, 'Offre pourvue', 'L’offre ' || new.subject || ' · ' || new.school_level || ' a été attribuée à un autre enseignant. Merci pour votre candidature !'
  from closed c where c.status = 'rejected';
  return new;
end;
$$;
drop trigger if exists close_applications on public.course_requests;
create trigger close_applications after update on public.course_requests
  for each row execute function public.close_applications();

-- ============================================================
-- Facturation mensuelle : tarif par cours, génération du mois, échéance, Moov Money
-- ============================================================
alter table public.course_requests add column if not exists monthly_fee integer check (monthly_fee is null or monthly_fee > 0);
alter table public.invoices add column if not exists due_date date;
-- Moov Money est proposé aux parents : il doit être accepté comme moyen de paiement
alter table public.invoices drop constraint if exists invoices_payment_method_check;
alter table public.invoices add constraint invoices_payment_method_check
  check (payment_method in ('wave','orange_money','mtn_money','moov_money')) not valid;

-- Factures du mois pour tous les cours en cours ayant un tarif mensuel (sans doublon)
create or replace function public.generate_month_invoices(p_month date)
returns integer language plpgsql security definer set search_path = public as $$
declare v_month date := date_trunc('month', p_month)::date; v_count integer;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  insert into public.invoices (course_request_id, parent_id, month, amount, due_date)
  select r.id, r.parent_id, v_month, r.monthly_fee, v_month + 9
  from public.course_requests r
  where r.status = 'assigned' and r.parent_id is not null and r.monthly_fee > 0
  on conflict (course_request_id, month) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke execute on function public.generate_month_invoices(date) from public;
grant execute on function public.generate_month_invoices(date) to authenticated;

-- Échéance par défaut : le 10 du mois facturé
create or replace function public.invoice_defaults() returns trigger
language plpgsql set search_path = public as $$
begin
  new.month := date_trunc('month', new.month)::date;
  if new.due_date is null then new.due_date := new.month + 9; end if;
  return new;
end;
$$;
drop trigger if exists invoice_defaults on public.invoices;
create trigger invoice_defaults before insert on public.invoices
  for each row execute function public.invoice_defaults();

-- ============================================================
-- Suivi des inscrits (administrateurs) : e-mail, date d'inscription, dernière connexion
-- ============================================================
create or replace function public.admin_users()
returns table (id uuid, email text, full_name text, phone text, role text, created_at timestamptz, last_sign_in_at timestamptz)
language sql stable security definer set search_path = public as $$
  select u.id, u.email::text, p.full_name, p.phone, coalesce(p.role, 'none'), u.created_at, u.last_sign_in_at
  from auth.users u left join public.profiles p on p.id = u.id
  where public.is_admin()
  order by u.created_at desc;
$$;
revoke execute on function public.admin_users() from public;
grant execute on function public.admin_users() to authenticated;

-- L'administrateur rétablit le profil d'un compte qui n'en a pas (rôle Parent ou Enseignant)
create or replace function public.admin_set_profile(p_id uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if p_role not in ('parent','teacher','seller') then raise exception 'Type de compte invalide'; end if;
  insert into public.profiles (id, full_name, role)
  select u.id, coalesce(nullif(u.raw_user_meta_data->>'full_name',''), split_part(u.email, '@', 1)), p_role
  from auth.users u where u.id = p_id
  on conflict (id) do update set role = excluded.role;
end;
$$;
revoke execute on function public.admin_set_profile(uuid, text) from public;
grant execute on function public.admin_set_profile(uuid, text) to authenticated;

-- ============================================================
-- Notifications par e-mail gratuites (Brevo : 300 e-mails/jour sans frais)
-- Chaque notification du site est aussi envoyée par e-mail dès qu'une clé Brevo est enregistrée.
-- ============================================================
do $$ begin
  create extension if not exists pg_net with schema extensions;
exception when others then raise notice 'pg_net indisponible : e-mails désactivés (%).', sqlerrm;
end $$;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table if not exists private.settings (key text primary key, value text not null);

-- Enregistrement des réglages par un administrateur (la clé n'est jamais relisible depuis le site)
create or replace function public.admin_save_email_settings(p_api_key text, p_sender text)
returns void language plpgsql security definer set search_path = public, private as $$
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if coalesce(trim(p_sender), '') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Adresse d’expéditeur invalide'; end if;
  if coalesce(trim(p_api_key), '') <> '' then
    insert into private.settings values ('brevo_api_key', trim(p_api_key)) on conflict (key) do update set value = excluded.value;
  end if;
  insert into private.settings values ('email_from', lower(trim(p_sender))) on conflict (key) do update set value = excluded.value;
end;
$$;
revoke execute on function public.admin_save_email_settings(text, text) from public;
grant execute on function public.admin_save_email_settings(text, text) to authenticated;

create or replace function public.admin_email_status()
returns table (enabled boolean, sender text) language sql stable security definer set search_path = public, private as $$
  select exists (select 1 from private.settings where key = 'brevo_api_key'),
         (select value from private.settings where key = 'email_from')
  where public.is_admin();
$$;
revoke execute on function public.admin_email_status() from public;
grant execute on function public.admin_email_status() to authenticated;

-- Envoi de l'e-mail à chaque nouvelle notification (ne bloque jamais la notification en cas d'erreur)
create or replace function public.email_notification() returns trigger
language plpgsql security definer set search_path = public, private, extensions as $$
declare v_key text; v_from text; v_to text; v_name text; v_html text;
  esc text := '';
begin
  select value into v_key from private.settings where key = 'brevo_api_key';
  if v_key is null then return new; end if;
  select value into v_from from private.settings where key = 'email_from';
  select u.email, p.full_name into v_to, v_name from auth.users u left join public.profiles p on p.id = u.id where u.id = new.recipient_id;
  if v_to is null or v_from is null then return new; end if;
  v_html := '<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;color:#0f1b37">'
    || '<p style="font-size:22px;font-weight:800;color:#1559eb;margin:0 0 18px">KONE.<span style="color:#fa7518">EDUC</span></p>'
    || '<p>Bonjour ' || replace(replace(coalesce(v_name, ''), '<', '&lt;'), '>', '&gt;') || ',</p>'
    || '<h2 style="font-size:19px;margin:18px 0 8px">' || replace(replace(new.title, '<', '&lt;'), '>', '&gt;') || '</h2>'
    || '<p style="font-size:15px;line-height:1.6">' || replace(replace(new.body, '<', '&lt;'), '>', '&gt;') || '</p>'
    || '<p style="margin:24px 0"><a href="https://www.kone-educ.com/connexion.html" style="background:#1559eb;color:#fff;padding:12px 18px;border-radius:10px;text-decoration:none;font-weight:700">Ouvrir mon espace</a></p>'
    || '<p style="color:#5b6884;font-size:13px">Une question ? WhatsApp : 01 61 70 13 61<br>KONE.EDUC — L’excellence à domicile</p></div>';
  perform net.http_post(
    url := 'https://api.brevo.com/v3/smtp/email',
    headers := jsonb_build_object('api-key', v_key, 'Content-Type', 'application/json', 'accept', 'application/json'),
    body := jsonb_build_object(
      'sender', jsonb_build_object('name', 'KONE.EDUC', 'email', v_from),
      'to', jsonb_build_array(jsonb_build_object('email', v_to, 'name', coalesce(v_name, v_to))),
      'subject', new.title || ' — KONE.EDUC',
      'htmlContent', v_html));
  return new;
exception when others then
  return new;
end;
$$;
drop trigger if exists email_notification on public.notifications;
create trigger email_notification after insert on public.notifications
  for each row execute function public.email_notification();

-- ============================================================
-- Notifications cliquables : chaque notification mène à la bonne page
-- ============================================================
alter table public.notifications add column if not exists link text;

create or replace function public.notification_link() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_role text;
begin
  if new.link is not null then return new; end if;
  select role into v_role from public.profiles where id = new.recipient_id;
  new.link := case
    when new.title in ('Nouvelle facture', 'Paiement confirmé', 'Rappel de paiement') then 'paiements.html'
    when new.title = 'Paiement à vérifier' then 'espace-admin.html#billing'
    when new.title in ('Nouvelle offre de cours', 'Offre pourvue') then 'offres.html'
    when new.title in ('Nouvel inscrit') then 'espace-admin.html#users'
    when new.title in ('Nouvelle demande de cours', 'Nouvelle candidature enseignant') then 'espace-admin.html'
    when new.title in ('Nouvelle demande d’une école', 'Enseignant intéressé par une école') then 'espace-admin.html#schools'
    when new.title in ('Mise en relation avec une école', 'Nouvelle offre d’école') then 'offres.html'
    when v_role = 'teacher' then 'espace-enseignant.html'
    when v_role = 'seller' then 'espace-vendeur.html'
    when v_role = 'admin' then 'espace-admin.html'
    else 'espace-parent.html' end;
  return new;
end;
$$;
drop trigger if exists notification_link on public.notifications;
create trigger notification_link before insert on public.notifications
  for each row execute function public.notification_link();

-- Message : mène directement à la conversation
create or replace function public.notify_new_message() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body, link)
  select new.recipient_id, 'Nouveau message',
         'Nouveau message concernant le cours de ' || cr.subject || ' pour ' || cr.student_name || ' : « ' || left(new.body, 120) || case when length(new.body) > 120 then '…' else '' end || ' »',
         'messagerie.html?cours=' || cr.id
  from public.course_requests cr where cr.id = new.course_request_id;
  return new;
end;
$$;

-- Compte rendu : mène au suivi des séances
create or replace function public.notify_session_report() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body, link)
  select cr.parent_id, 'Nouveau compte rendu',
         'Séance de ' || cr.subject || ' du ' || to_char(new.session_date, 'DD/MM/YYYY') || ' pour ' || cr.student_name || ' : ' || new.topics,
         'suivi.html?cours=' || cr.id
  from public.course_requests cr where cr.id = new.course_request_id and cr.parent_id is not null;
  return new;
end;
$$;

-- Administrateurs prévenus : nouvel inscrit, nouvelle demande, nouvelle candidature
create or replace function public.notify_admins_new_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role = 'admin' then return new; end if;
  insert into public.notifications (recipient_id, title, body)
  select a.id, 'Nouvel inscrit', coalesce(new.full_name, 'Un utilisateur') || ' vient de créer un compte ' || case new.role when 'teacher' then 'Enseignant' when 'seller' then 'Vendeur' else 'Parent' end || coalesce(' · ' || new.phone, '') || '.'
  from public.profiles a where a.role = 'admin';
  return new;
end;
$$;
drop trigger if exists notify_admins_new_profile on public.profiles;
create trigger notify_admins_new_profile after insert on public.profiles
  for each row execute function public.notify_admins_new_profile();

create or replace function public.notify_admins_new_request() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body)
  select a.id, 'Nouvelle demande de cours', new.subject || ' · ' || new.school_level || ' · ' || new.location || ' pour ' || new.student_name || '. Attribuez un enseignant.'
  from public.profiles a where a.role = 'admin';
  return new;
end;
$$;
drop trigger if exists notify_admins_new_request on public.course_requests;
create trigger notify_admins_new_request after insert on public.course_requests
  for each row execute function public.notify_admins_new_request();

create or replace function public.notify_admins_new_candidate() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body)
  select a.id, 'Nouvelle candidature enseignant', coalesce(p.full_name, 'Un enseignant') || ' · ' || coalesce(new.subject, 'matière ?') || ' · ' || coalesce(new.degree, '') || '. Dossier à étudier.'
  from public.profiles a left join public.profiles p on p.id = new.id where a.role = 'admin';
  return new;
end;
$$;
drop trigger if exists notify_admins_new_candidate on public.teacher_profiles;
create trigger notify_admins_new_candidate after insert on public.teacher_profiles
  for each row execute function public.notify_admins_new_candidate();

-- ============================================================
-- Journal des actions : qui a fait quoi, et quand (y compris les suppressions)
-- ============================================================
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_id uuid,
  actor_name text,
  action text not null,
  table_name text not null,
  record_id text,
  summary text,
  changes jsonb
);
alter table public.audit_log enable row level security;
grant select on public.audit_log to authenticated;
drop policy if exists "Admins read audit log" on public.audit_log;
create policy "Admins read audit log" on public.audit_log for select to authenticated using (public.is_admin());
create index if not exists audit_log_at_idx on public.audit_log (at desc);

create or replace function public.audit_changes() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_old jsonb; v_new jsonb; v_diff jsonb := '{}'::jsonb; k text; v_id text; v_actor uuid := auth.uid(); v_name text; v_sum text;
begin
  v_old := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end;
  v_new := case when tg_op in ('UPDATE','INSERT') then to_jsonb(new) end;
  v_id := coalesce(v_new->>'id', v_old->>'id');
  if tg_op = 'UPDATE' then
    for k in select jsonb_object_keys(v_new) loop
      if k not in ('updated_at') and (v_new->k) is distinct from (v_old->k) then
        v_diff := v_diff || jsonb_build_object(k, jsonb_build_object('avant', v_old->k, 'après', v_new->k));
      end if;
    end loop;
    if v_diff = '{}'::jsonb then return new; end if;
  elsif tg_op = 'DELETE' then v_diff := v_old;
  else v_diff := v_new;
  end if;
  -- Les textes longs et les chemins de documents ne sont pas recopiés
  v_diff := v_diff - 'bio' - 'details' - 'message' - 'comment';
  select full_name into v_name from public.profiles where id = v_actor;
  v_sum := coalesce(v_new->>'full_name', v_old->>'full_name', v_new->>'student_name', v_old->>'student_name', v_new->>'name', v_old->>'name');
  if v_sum is null and tg_table_name in ('teacher_profiles', 'course_applications') then
    select full_name into v_sum from public.profiles where id = coalesce(v_new->>'teacher_id', v_old->>'teacher_id', v_id)::uuid;
  end if;
  if tg_table_name = 'invoices' then
    v_sum := coalesce(v_new->>'amount', v_old->>'amount') || ' FCFA · ' || to_char(coalesce(v_new->>'month', v_old->>'month')::date, 'MM/YYYY');
  end if;
  insert into public.audit_log (actor_id, actor_name, action, table_name, record_id, summary, changes)
  values (v_actor, case when v_actor is null then 'Tableau de bord Supabase / système' else coalesce(v_name, 'Utilisateur') end,
          tg_op, tg_table_name, v_id, v_sum, v_diff);
  return coalesce(new, old);
exception when others then
  return coalesce(new, old);
end;
$$;

do $$ declare t text; begin
  foreach t in array array['profiles','teacher_profiles','course_requests','invoices','course_applications','session_reports','reviews','documents','contact_messages'] loop
    execute format('drop trigger if exists audit_changes on public.%I', t);
    execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function public.audit_changes()', t);
  end loop;
end $$;

-- Suppression d'un compte (y compris depuis le tableau de bord Supabase)
create or replace function public.audit_user_delete() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_actor uuid := auth.uid(); v_name text;
begin
  select full_name into v_name from public.profiles where id = v_actor;
  insert into public.audit_log (actor_id, actor_name, action, table_name, record_id, summary, changes)
  values (v_actor, case when v_actor is null then 'Tableau de bord Supabase / système' else coalesce(v_name, 'Utilisateur') end,
          'DELETE', 'comptes', old.id::text, old.email, jsonb_build_object('email', old.email, 'inscrit_le', old.created_at));
  return old;
exception when others then return old;
end;
$$;
do $$ begin
  drop trigger if exists audit_user_delete on auth.users;
  create trigger audit_user_delete before delete on auth.users for each row execute function public.audit_user_delete();
exception when others then raise notice 'Journal des suppressions de comptes indisponible (%).', sqlerrm;
end $$;

-- ============================================================
-- Planning des séances et rappels automatiques
-- ============================================================
create table if not exists public.sessions (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  starts_at timestamptz not null,
  duration_minutes integer not null default 60 check (duration_minutes between 15 and 480),
  status text not null default 'planned' check (status in ('planned','done','absent','cancelled')),
  note text check (char_length(note) <= 300),
  change_request text check (char_length(change_request) <= 400),
  reminded_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists sessions_course_idx on public.sessions (course_request_id, starts_at);
create index if not exists sessions_starts_idx on public.sessions (starts_at);
alter table public.sessions enable row level security;
grant select, update on public.sessions to authenticated;
grant delete on public.sessions to authenticated;

create or replace function public.course_role(p_course bigint) returns text
language sql stable security definer set search_path = public as $$
  select case when public.is_admin() then 'admin'
              when cr.teacher_id = auth.uid() then 'teacher'
              when cr.parent_id = auth.uid() then 'parent' end
  from public.course_requests cr where cr.id = p_course;
$$;

drop policy if exists "Course participants read sessions" on public.sessions;
create policy "Course participants read sessions" on public.sessions for select to authenticated
  using (public.course_role(course_request_id) is not null);
drop policy if exists "Teachers and admins update sessions" on public.sessions;
create policy "Teachers and admins update sessions" on public.sessions for update to authenticated
  using (public.course_role(course_request_id) in ('teacher','admin'))
  with check (public.course_role(course_request_id) in ('teacher','admin'));
drop policy if exists "Admins delete sessions" on public.sessions;
create policy "Admins delete sessions" on public.sessions for delete to authenticated using (public.is_admin());

-- Seuls l'horaire, la durée, le statut et la note se modifient ; une demande traitée est effacée
create or replace function public.protect_session() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.course_request_id <> old.course_request_id then raise exception 'Le cours d’une séance ne peut pas être changé'; end if;
  if auth.uid() is not null and new.reminded_at is distinct from old.reminded_at then new.reminded_at := old.reminded_at; end if;
  if new.starts_at <> old.starts_at then new.reminded_at := null; end if;
  if new.starts_at <> old.starts_at or new.status <> old.status then new.change_request := null; end if;
  return new;
end;
$$;
drop trigger if exists protect_session on public.sessions;
create trigger protect_session before update on public.sessions
  for each row execute function public.protect_session();

create or replace function public.session_label(p_at timestamptz) returns text
language sql immutable as $$
  select to_char(p_at at time zone 'Africa/Abidjan', 'DD/MM/YYYY "à" HH24"h"MI');
$$;

-- Planifier plusieurs séances d'un coup (enseignant du cours ou administrateur)
create or replace function public.plan_sessions(p_course bigint, p_starts timestamptz[], p_duration integer default 60)
returns integer language plpgsql security definer set search_path = public as $$
declare v_role text := public.course_role(p_course); v_cr public.course_requests; v_count integer; v_first timestamptz;
begin
  if v_role not in ('teacher','admin') or v_role is null then raise exception 'Seul l’enseignant du cours peut planifier ses séances'; end if;
  select * into v_cr from public.course_requests where id = p_course;
  if v_cr.status <> 'assigned' then raise exception 'Le cours doit être en cours (enseignant attribué)'; end if;
  if coalesce(array_length(p_starts, 1), 0) = 0 or array_length(p_starts, 1) > 60 then raise exception 'Entre 1 et 60 séances à la fois'; end if;
  insert into public.sessions (course_request_id, starts_at, duration_minutes)
  select p_course, t, greatest(15, least(480, coalesce(p_duration, 60)))
  from (select distinct u as t from unnest(p_starts) as u) as d
  where t > now() - interval '1 day'
    and not exists (select 1 from public.sessions s where s.course_request_id = p_course and s.starts_at = t and s.status <> 'cancelled');
  get diagnostics v_count = row_count;
  select min(t) into v_first from unnest(p_starts) as t where t > now();
  if v_count > 0 then
    insert into public.notifications (recipient_id, title, body, link)
    select x, 'Séances planifiées', v_count || ' séance(s) de ' || v_cr.subject || ' pour ' || v_cr.student_name || ' ajoutée(s) au planning.'
           || coalesce(' Prochaine : ' || public.session_label(v_first) || '.', ''), 'planning.html'
    from unnest(array[v_cr.parent_id, case when v_role = 'admin' then v_cr.teacher_id end]) as x where x is not null;
  end if;
  return v_count;
end;
$$;
revoke execute on function public.plan_sessions(bigint, timestamptz[], integer) from public;
grant execute on function public.plan_sessions(bigint, timestamptz[], integer) to authenticated;

-- Le parent demande un report ou une annulation
create or replace function public.request_session_change(p_session bigint, p_kind text, p_message text)
returns void language plpgsql security definer set search_path = public as $$
declare v_s public.sessions; v_cr public.course_requests; v_title text;
begin
  select * into v_s from public.sessions where id = p_session;
  if v_s.id is null or public.course_role(v_s.course_request_id) not in ('parent','admin') then raise exception 'Séance introuvable'; end if;
  if v_s.status <> 'planned' then raise exception 'Cette séance n’est plus modifiable'; end if;
  if p_kind not in ('report','cancel') then raise exception 'Demande invalide'; end if;
  select * into v_cr from public.course_requests where id = v_s.course_request_id;
  v_title := case p_kind when 'report' then 'Demande de report' else 'Demande d’annulation' end;
  update public.sessions set change_request = v_title || coalesce(' : ' || nullif(trim(left(p_message, 300)), ''), '') where id = p_session;
  insert into public.notifications (recipient_id, title, body, link)
  select x, v_title, v_cr.subject || ' pour ' || v_cr.student_name || ', séance du ' || public.session_label(v_s.starts_at)
         || coalesce(' : « ' || nullif(trim(left(p_message, 200)), '') || ' »', '') || '.', 'planning.html'
  from (select v_cr.teacher_id as x union select id from public.profiles where role = 'admin') r where x is not null;
end;
$$;
revoke execute on function public.request_session_change(bigint, text, text) from public;
grant execute on function public.request_session_change(bigint, text, text) to authenticated;

-- Prévenir l'autre partie d'un déplacement, d'une annulation ou d'une absence
create or replace function public.notify_session_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_cr public.course_requests; v_title text; v_body text;
begin
  select * into v_cr from public.course_requests where id = new.course_request_id;
  if new.status = 'cancelled' and old.status <> 'cancelled' then
    v_title := 'Cours annulé'; v_body := 'La séance de ' || v_cr.subject || ' pour ' || v_cr.student_name || ' du ' || public.session_label(old.starts_at) || ' est annulée.';
  elsif new.status = 'absent' and old.status <> 'absent' then
    v_title := 'Absence signalée'; v_body := 'Absence signalée à la séance de ' || v_cr.subject || ' du ' || public.session_label(new.starts_at) || ' pour ' || v_cr.student_name || '.';
  elsif new.starts_at <> old.starts_at and new.status = 'planned' then
    v_title := 'Cours déplacé'; v_body := 'La séance de ' || v_cr.subject || ' pour ' || v_cr.student_name || ' est déplacée au ' || public.session_label(new.starts_at) || '.';
  else return new;
  end if;
  insert into public.notifications (recipient_id, title, body, link)
  select x, v_title, v_body, 'planning.html'
  from unnest(array[v_cr.parent_id, v_cr.teacher_id]) as x where x is not null and x is distinct from auth.uid();
  return new;
end;
$$;
drop trigger if exists notify_session_change on public.sessions;
create trigger notify_session_change after update on public.sessions
  for each row execute function public.notify_session_change();

-- Rappels automatiques : cours du lendemain, factures en retard (une fois par semaine)
alter table public.invoices add column if not exists last_reminder_at timestamptz;
create or replace function public.send_reminders() returns integer
language plpgsql security definer set search_path = public as $$
declare v_n integer := 0; v_k integer;
begin
  with due as (
    update public.sessions s set reminded_at = now()
    where s.status = 'planned' and s.reminded_at is null
      and s.starts_at between now() + interval '12 hours' and now() + interval '36 hours'
    returning s.course_request_id, s.starts_at)
  insert into public.notifications (recipient_id, title, body, link)
  select x, 'Rappel de cours', 'Cours de ' || cr.subject || ' pour ' || cr.student_name || ' le ' || public.session_label(d.starts_at) || '. Pensez-y !', 'planning.html'
  from due d join public.course_requests cr on cr.id = d.course_request_id
  cross join lateral unnest(array[cr.parent_id, cr.teacher_id]) as x where x is not null;
  get diagnostics v_k = row_count; v_n := v_n + v_k;
  with late as (
    update public.invoices i set last_reminder_at = now()
    where i.status = 'unpaid' and i.due_date < current_date
      and (i.last_reminder_at is null or i.last_reminder_at < now() - interval '7 days')
    returning i.parent_id, i.amount, i.month, i.due_date)
  insert into public.notifications (recipient_id, title, body, link)
  select l.parent_id, 'Rappel de paiement', 'Votre facture de ' || to_char(l.month, 'MM/YYYY') || ' (' || l.amount || ' FCFA) était à régler le ' || to_char(l.due_date, 'DD/MM') || '. Merci de la régler dans « Mes paiements ».', 'paiements.html'
  from late l;
  get diagnostics v_k = row_count; v_n := v_n + v_k;
  return v_n;
end;
$$;
revoke execute on function public.send_reminders() from public;
create or replace function public.admin_send_reminders() returns integer
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  return public.send_reminders();
end;
$$;
revoke execute on function public.admin_send_reminders() from public;
grant execute on function public.admin_send_reminders() to authenticated;

-- Exécution automatique toutes les heures (pg_cron, gratuit sur Supabase)
do $$ begin
  begin create extension if not exists pg_cron with schema pg_catalog; exception when others then create extension if not exists pg_cron; end;
  perform cron.schedule('kone-educ-rappels', '7 * * * *', 'select public.send_reminders()');
exception when others then raise notice 'Rappels automatiques indisponibles (pg_cron : %).', sqlerrm;
end $$;

-- ============================================================
-- Bilan de progression mensuel (appréciation de l'enseignant)
-- ============================================================
create table if not exists public.monthly_assessments (
  id bigint generated always as identity primary key,
  course_request_id bigint not null references public.course_requests(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  teacher_id uuid references public.profiles(id) on delete set null,
  appreciation text not null check (char_length(appreciation) between 1 and 1500),
  strengths text check (char_length(strengths) <= 600),
  improvements text check (char_length(improvements) <= 600),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_request_id, month)
);
alter table public.monthly_assessments enable row level security;
grant select, insert, update on public.monthly_assessments to authenticated;
grant usage, select on sequence public.monthly_assessments_id_seq to authenticated;
drop policy if exists "Course participants read assessments" on public.monthly_assessments;
create policy "Course participants read assessments" on public.monthly_assessments for select to authenticated
  using (public.course_role(course_request_id) is not null);
drop policy if exists "Teachers write assessments" on public.monthly_assessments;
create policy "Teachers write assessments" on public.monthly_assessments for insert to authenticated
  with check (public.course_role(course_request_id) in ('teacher','admin'));
drop policy if exists "Teachers update assessments" on public.monthly_assessments;
create policy "Teachers update assessments" on public.monthly_assessments for update to authenticated
  using (public.course_role(course_request_id) in ('teacher','admin'))
  with check (public.course_role(course_request_id) in ('teacher','admin'));

create or replace function public.notify_assessment() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_cr public.course_requests; v_mois text;
begin
  if tg_op = 'UPDATE' then
    if new.course_request_id <> old.course_request_id or new.month <> old.month then raise exception 'Le cours et le mois d’un bilan ne changent pas'; end if;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  new.teacher_id := (select teacher_id from public.course_requests where id = new.course_request_id);
  if tg_op = 'INSERT' then
    select * into v_cr from public.course_requests where id = new.course_request_id;
    v_mois := to_char(new.month, 'MM/YYYY');
    if v_cr.parent_id is not null then
      insert into public.notifications (recipient_id, title, body, link)
      values (v_cr.parent_id, 'Bilan du mois disponible',
              'Le bilan de progression de ' || v_cr.student_name || ' en ' || v_cr.subject || ' (' || v_mois || ') est disponible.',
              'bilan.html?cours=' || new.course_request_id || '&mois=' || to_char(new.month, 'YYYY-MM'));
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists notify_assessment on public.monthly_assessments;
create trigger notify_assessment before insert or update on public.monthly_assessments
  for each row execute function public.notify_assessment();

do $$ begin
  drop trigger if exists audit_changes on public.monthly_assessments;
  create trigger audit_changes after insert or update or delete on public.monthly_assessments
    for each row execute function public.audit_changes();
exception when others then raise notice 'Journal des bilans indisponible (%).', sqlerrm;
end $$;

-- ============================================================
-- Fiche publique de l'enseignant, avis vérifiés, « Demander cet enseignant »
-- ============================================================
-- Le parent choisit de publier son avis (prénom + initiale seulement) ; l'équipe peut le masquer
alter table public.reviews add column if not exists is_public boolean not null default false;
drop policy if exists "Admins update reviews" on public.reviews;
create policy "Admins update reviews" on public.reviews for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Enseignant souhaité par le parent lors de sa demande (uniquement un enseignant validé)
alter table public.course_requests add column if not exists preferred_teacher_id uuid references public.profiles(id) on delete set null;
create or replace function public.check_preferred_teacher() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.preferred_teacher_id is not null
     and (tg_op = 'INSERT' or new.preferred_teacher_id is distinct from old.preferred_teacher_id)
     and not exists (select 1 from public.teacher_profiles tp join public.profiles p on p.id = tp.id
                     where tp.id = new.preferred_teacher_id and tp.approved and p.role = 'teacher') then
    new.preferred_teacher_id := null;
  end if;
  return new;
end;
$$;
drop trigger if exists check_preferred_teacher on public.course_requests;
create trigger check_preferred_teacher before insert or update on public.course_requests
  for each row execute function public.check_preferred_teacher();

create or replace function public.notify_admins_new_request() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_pref text;
begin
  select full_name into v_pref from public.profiles where id = new.preferred_teacher_id;
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, 'Nouvelle demande de cours', new.subject || ' · ' || new.school_level || ' · ' || new.location || ' pour ' || new.student_name || '.'
         || case when v_pref is not null then ' Enseignant souhaité : ' || v_pref || '.' else ' Attribuez un enseignant.' end,
         'espace-admin.html'
  from public.profiles a where a.role = 'admin';
  return new;
end;
$$;

-- Nom public : prénom + initiale du nom
create or replace function public.short_name(p_full text) returns text
language sql immutable as $$
  select case when n = '' then 'Parent'
              else split_part(n, ' ', 1) || case when position(' ' in n) > 0 then ' ' || upper(left(split_part(n, ' ', 2), 1)) || '.' else '' end end
  from (select regexp_replace(trim(coalesce(p_full, '')), '\s+', ' ', 'g') as n) x;
$$;

-- Fiche publique d'un enseignant validé : aucune donnée sensible (ni téléphone, ni documents)
create or replace function public.public_teacher_profile(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', tp.id,
    'display_name', public.short_name(p.full_name),
    'subject', tp.subject, 'degree', tp.degree, 'experience', tp.experience, 'levels', tp.levels,
    'location', tp.location, 'format', tp.format, 'availability', tp.availability, 'bio', tp.bio, 'photo_url', tp.photo_url,
    'member_since', p.created_at,
    'diploma_checked', tp.diploma_path is not null, 'id_checked', tp.id_doc_path is not null,
    'rating', (select round(avg(r.rating)::numeric, 1) from public.reviews r where r.teacher_id = tp.id),
    'reviews_count', (select count(*) from public.reviews r where r.teacher_id = tp.id),
    'stars', (select jsonb_build_array(
                count(*) filter (where rating = 5), count(*) filter (where rating = 4), count(*) filter (where rating = 3),
                count(*) filter (where rating = 2), count(*) filter (where rating = 1))
              from public.reviews r where r.teacher_id = tp.id),
    'students', (select count(distinct cr.id) from public.course_requests cr where cr.teacher_id = tp.id and cr.status in ('assigned','completed')),
    'sessions', (select count(*) from public.session_reports sr where sr.teacher_id = tp.id),
    'reviews', coalesce((select jsonb_agg(jsonb_build_object(
                  'id', r.id, 'rating', r.rating, 'comment', r.comment, 'created_at', r.created_at,
                  'author', public.short_name(pp.full_name), 'level', cr.school_level, 'subject', cr.subject) order by r.created_at desc)
                from public.reviews r
                join public.course_requests cr on cr.id = r.course_request_id
                left join public.profiles pp on pp.id = r.parent_id
                where r.teacher_id = tp.id and r.is_public), '[]'::jsonb))
  from public.teacher_profiles tp join public.profiles p on p.id = tp.id
  where tp.id = p_id and tp.approved and p.role = 'teacher';
$$;
revoke execute on function public.public_teacher_profile(uuid) from public;
grant execute on function public.public_teacher_profile(uuid) to anon, authenticated;

-- ============================================================
-- Documents : à tout le monde, à tous les parents / enseignants, ou à une personne précise
-- ============================================================
alter table public.documents add column if not exists recipient_id uuid references public.profiles(id) on delete cascade;
alter table public.documents drop constraint if exists documents_audience_check;
alter table public.documents add constraint documents_audience_check
  check (audience in ('parent','teacher','all','person') and ((audience = 'person') = (recipient_id is not null)));
drop policy if exists "Users read intended documents" on public.documents;
create policy "Users read intended documents" on public.documents for select to authenticated
  using (audience = 'all' or recipient_id = auth.uid() or public.is_admin()
         or (audience in ('parent','teacher') and audience = (select role from public.profiles where id = auth.uid())));

-- Espace de stockage privé des documents (jusqu'à 10 Mo par fichier)
insert into storage.buckets (id, name, public, file_size_limit)
values ('documents', 'documents', false, 10485760)
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;
drop policy if exists "Admins manage document files" on storage.objects;
create policy "Admins manage document files" on storage.objects for all to authenticated
  using (bucket_id = 'documents' and public.is_admin()) with check (bucket_id = 'documents' and public.is_admin());
drop policy if exists "Users read intended document files" on storage.objects;
create policy "Users read intended document files" on storage.objects for select to authenticated
  using (bucket_id = 'documents' and exists (select 1 from public.documents d where d.storage_path = name));

-- Les destinataires sont prévenus (notification + e-mail si activé)
create or replace function public.notify_new_document() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body, link)
  select p.id, 'Nouveau document', '« ' || new.title || ' » est disponible dans vos ressources.', 'ressources.html'
  from public.profiles p
  where p.role <> 'admin'
    and (new.recipient_id = p.id
         or (new.recipient_id is null and (new.audience = 'all' or new.audience = p.role)));
  return new;
end;
$$;
drop trigger if exists notify_new_document on public.documents;
create trigger notify_new_document after insert on public.documents
  for each row execute function public.notify_new_document();

-- ============================================================
-- Demande de suppression de compte (exigée par Google Play)
-- ============================================================
alter table public.profiles add column if not exists deletion_requested_at timestamptz;
create or replace function public.request_account_deletion(p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_p public.profiles; v_email text;
begin
  select * into v_p from public.profiles where id = auth.uid();
  if v_p.id is null then raise exception 'Connectez-vous pour demander la suppression de votre compte'; end if;
  if v_p.role = 'admin' then raise exception 'Un compte administrateur se supprime depuis Supabase'; end if;
  select email into v_email from auth.users where id = v_p.id;
  update public.profiles set deletion_requested_at = now() where id = v_p.id;
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, 'Demande de suppression de compte',
         coalesce(v_p.full_name, 'Un utilisateur') || ' (' || case v_p.role when 'teacher' then 'Enseignant' else 'Parent' end
         || coalesce(' · ' || v_email, '') || coalesce(' · ' || v_p.phone, '') || ') demande la suppression de son compte.'
         || coalesce(' Motif : « ' || nullif(trim(left(p_reason, 300)), '') || ' ».', '') || ' À traiter sous 30 jours.',
         'espace-admin.html'
  from public.profiles a where a.role = 'admin';
  insert into public.notifications (recipient_id, title, body)
  values (v_p.id, 'Demande de suppression reçue', 'Votre demande de suppression de compte a bien été reçue. Elle sera traitée sous 30 jours ; nous vous contacterons si nécessaire.');
end;
$$;
revoke execute on function public.request_account_deletion(text) from public;
grant execute on function public.request_account_deletion(text) to authenticated;

-- ============================================================
-- Rémunération des enseignants et versements (jamais visibles par les parents)
-- ============================================================
create table if not exists public.teacher_rates (
  course_request_id bigint primary key references public.course_requests(id) on delete cascade,
  monthly_amount integer not null check (monthly_amount > 0),
  updated_at timestamptz not null default now()
);
alter table public.teacher_rates enable row level security;
grant select, insert, update, delete on public.teacher_rates to authenticated;
drop policy if exists "Admins manage teacher rates" on public.teacher_rates;
create policy "Admins manage teacher rates" on public.teacher_rates for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Teachers read own rates" on public.teacher_rates;
create policy "Teachers read own rates" on public.teacher_rates for select to authenticated
  using (public.course_role(course_request_id) = 'teacher');

create table if not exists public.teacher_payouts (
  id bigint generated always as identity primary key,
  teacher_id uuid references public.profiles(id) on delete set null,
  teacher_name text not null,
  course_request_id bigint references public.course_requests(id) on delete set null,
  month date not null check (extract(day from month) = 1),
  amount integer not null check (amount > 0),
  label text not null check (char_length(label) <= 200),
  status text not null default 'due' check (status in ('due','paid')),
  payment_method text check (payment_method in ('wave','orange_money','mtn_money','moov_money')),
  payment_reference text check (char_length(payment_reference) <= 100),
  paid_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists teacher_payouts_course_month on public.teacher_payouts (course_request_id, month) where course_request_id is not null;
create index if not exists teacher_payouts_teacher on public.teacher_payouts (teacher_id, month);
alter table public.teacher_payouts enable row level security;
grant select, insert, update, delete on public.teacher_payouts to authenticated;
grant usage, select on sequence public.teacher_payouts_id_seq to authenticated;
drop policy if exists "Admins manage payouts" on public.teacher_payouts;
create policy "Admins manage payouts" on public.teacher_payouts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Teachers read own payouts" on public.teacher_payouts;
create policy "Teachers read own payouts" on public.teacher_payouts for select to authenticated
  using (teacher_id = auth.uid());

-- Versements dus du mois : un par cours en cours ayant une rémunération, sans doublon
create or replace function public.generate_month_payouts(p_month date) returns integer
language plpgsql security definer set search_path = public as $$
declare v_month date := date_trunc('month', p_month)::date; v_n integer;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  insert into public.teacher_payouts (teacher_id, teacher_name, course_request_id, month, amount, label)
  select cr.teacher_id, coalesce(p.full_name, 'Enseignant'), cr.id, v_month, tr.monthly_amount,
         cr.subject || ' · ' || cr.student_name || ' (' || cr.school_level || ')'
  from public.course_requests cr
  join public.teacher_rates tr on tr.course_request_id = cr.id
  left join public.profiles p on p.id = cr.teacher_id
  where cr.status = 'assigned' and cr.teacher_id is not null
  on conflict (course_request_id, month) where course_request_id is not null do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function public.generate_month_payouts(date) from public;
grant execute on function public.generate_month_payouts(date) to authenticated;

-- Versement effectué : date automatique et notification à l'enseignant
create or replace function public.notify_payout() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'paid' and new.paid_at is null then new.paid_at := now(); end if;
  if new.status = 'due' then new.paid_at := null; end if;
  if tg_op = 'UPDATE' and new.status = 'paid' and old.status <> 'paid' and new.teacher_id is not null then
    insert into public.notifications (recipient_id, title, body, link)
    values (new.teacher_id, 'Versement effectué',
            new.amount || ' FCFA vous ont été versés pour ' || new.label || ' (' || to_char(new.month, 'MM/YYYY') || ')'
            || coalesce(' · référence ' || nullif(new.payment_reference, ''), '') || '.', 'versements.html');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_payout on public.teacher_payouts;
create trigger notify_payout before insert or update on public.teacher_payouts
  for each row execute function public.notify_payout();

do $$ begin
  drop trigger if exists audit_changes on public.teacher_payouts;
  create trigger audit_changes after insert or update or delete on public.teacher_payouts for each row execute function public.audit_changes();
  drop trigger if exists audit_changes on public.teacher_rates;
  create trigger audit_changes after insert or update or delete on public.teacher_rates for each row execute function public.audit_changes();
exception when others then raise notice 'Journal des versements indisponible (%).', sqlerrm;
end $$;

-- ============================================================
-- Satisfaction après le premier cours (👍 / 👎) : alerte immédiate de l'équipe
-- ============================================================
create table if not exists public.first_lesson_feedback (
  course_request_id bigint primary key references public.course_requests(id) on delete cascade,
  parent_id uuid references public.profiles(id) on delete set null,
  teacher_id uuid references public.profiles(id) on delete set null,
  asked_at timestamptz not null default now(),
  answer text check (answer in ('good','bad')),
  comment text check (char_length(comment) <= 600),
  wants_change boolean not null default false,
  answered_at timestamptz,
  handled_at timestamptz
);
alter table public.first_lesson_feedback enable row level security;
grant select on public.first_lesson_feedback to authenticated;
grant update on public.first_lesson_feedback to authenticated;
drop policy if exists "Parents and admins read first feedback" on public.first_lesson_feedback;
create policy "Parents and admins read first feedback" on public.first_lesson_feedback for select to authenticated
  using (parent_id = auth.uid() or public.is_admin());
drop policy if exists "Admins update first feedback" on public.first_lesson_feedback;
create policy "Admins update first feedback" on public.first_lesson_feedback for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Demande au parent, une seule fois par cours, dès le premier cours fait
create or replace function public.ask_first_feedback(p_course bigint) returns void
language plpgsql security definer set search_path = public as $$
declare v_cr public.course_requests; v_n integer;
begin
  select * into v_cr from public.course_requests where id = p_course;
  if v_cr.id is null or v_cr.parent_id is null or v_cr.teacher_id is null then return; end if;
  -- Seulement au tout premier cours (pas pour les cours déjà en route)
  if (select count(*) from public.sessions where course_request_id = p_course and status = 'done') > 1
     or (select count(*) from public.session_reports where course_request_id = p_course) > 1 then return; end if;
  insert into public.first_lesson_feedback (course_request_id, parent_id, teacher_id)
  values (p_course, v_cr.parent_id, v_cr.teacher_id) on conflict (course_request_id) do nothing;
  get diagnostics v_n = row_count;
  if v_n = 0 then return; end if;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_cr.parent_id, 'Comment s’est passé le premier cours ?',
          'Le premier cours de ' || v_cr.subject || ' de ' || v_cr.student_name || ' a eu lieu. Dites-nous en un clic s’il s’est bien passé : 👍 ou 👎.',
          'avis-premier-cours.html?cours=' || p_course);
end;
$$;
revoke execute on function public.ask_first_feedback(bigint) from public;

create or replace function public.first_feedback_on_session() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'done' and old.status is distinct from 'done' then perform public.ask_first_feedback(new.course_request_id); end if;
  return new;
end;
$$;
drop trigger if exists first_feedback_on_session on public.sessions;
create trigger first_feedback_on_session after update on public.sessions
  for each row execute function public.first_feedback_on_session();

create or replace function public.first_feedback_on_report() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.ask_first_feedback(new.course_request_id);
  return new;
end;
$$;
drop trigger if exists first_feedback_on_report on public.session_reports;
create trigger first_feedback_on_report after insert on public.session_reports
  for each row execute function public.first_feedback_on_report();

-- Réponse du parent : 👎 alerte immédiatement l'équipe ; 👍 encourage l'enseignant
create or replace function public.answer_first_feedback(p_course bigint, p_answer text, p_comment text default null, p_wants_change boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare v_f public.first_lesson_feedback; v_cr public.course_requests; v_teacher text; v_parent text; v_phone text;
begin
  select * into v_f from public.first_lesson_feedback where course_request_id = p_course;
  if v_f.course_request_id is null or v_f.parent_id is distinct from auth.uid() then raise exception 'Avis introuvable'; end if;
  if v_f.answered_at is not null then raise exception 'Vous avez déjà donné votre avis, merci !'; end if;
  if p_answer not in ('good','bad') then raise exception 'Réponse invalide'; end if;
  update public.first_lesson_feedback
  set answer = p_answer, comment = nullif(trim(left(p_comment, 600)), ''), wants_change = (p_answer = 'bad' and coalesce(p_wants_change, false)), answered_at = now()
  where course_request_id = p_course;
  select * into v_cr from public.course_requests where id = p_course;
  select full_name into v_teacher from public.profiles where id = v_cr.teacher_id;
  select full_name, phone into v_parent, v_phone from public.profiles where id = v_cr.parent_id;
  if p_answer = 'bad' then
    insert into public.notifications (recipient_id, title, body, link)
    select a.id, '⚠ Premier cours insatisfaisant',
           coalesce(v_parent, 'Un parent') || coalesce(' (' || v_phone || ')', '') || ' signale un premier cours insatisfaisant : ' || v_cr.subject
           || ' de ' || v_cr.student_name || ' avec ' || coalesce(v_teacher, 'l’enseignant') || '.'
           || case when p_wants_change then ' Demande un changement d’enseignant.' else '' end
           || coalesce(' « ' || nullif(trim(left(p_comment, 300)), '') || ' »', '') || ' À rappeler rapidement.',
           'espace-admin.html'
    from public.profiles a where a.role = 'admin';
  else
    insert into public.notifications (recipient_id, title, body, link)
    select a.id, '👍 Premier cours réussi', coalesce(v_parent, 'Le parent') || ' : premier cours satisfaisant en ' || v_cr.subject || ' de ' || v_cr.student_name || ' avec ' || coalesce(v_teacher, 'l’enseignant') || '.', 'espace-admin.html'
    from public.profiles a where a.role = 'admin';
    if v_cr.teacher_id is not null then
      insert into public.notifications (recipient_id, title, body, link)
      values (v_cr.teacher_id, 'Bravo pour votre premier cours ! 🎉', 'Le premier cours de ' || v_cr.subject || ' avec ' || v_cr.student_name || ' a plu à la famille. Continuez ainsi !', 'espace-enseignant.html');
    end if;
  end if;
end;
$$;
revoke execute on function public.answer_first_feedback(bigint, text, text, boolean) from public;
grant execute on function public.answer_first_feedback(bigint, text, text, boolean) to authenticated;

-- ============================================================
-- Boutique : des vendeurs (librairies, papeteries…) vendent livres, cahiers,
-- documents et fournitures aux parents et aux enseignants.
-- Commande en ligne, paiement à la livraison ou par mobile money, livraison par le vendeur.
-- ============================================================
create table if not exists public.shops (
  id bigint generated always as identity primary key,
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 80),
  description text check (length(description) <= 600),
  phone text not null check (length(trim(phone)) between 8 and 30),
  whatsapp text check (length(whatsapp) <= 30),
  commune text not null check (length(commune) <= 80),
  quartier text check (length(quartier) <= 80),
  address text check (length(address) <= 200),
  logo_url text,
  status text not null default 'pending' check (status in ('pending','approved','suspended')),
  is_open boolean not null default true,
  pickup boolean not null default true,
  delivery_fees jsonb not null default '{}'::jsonb,
  default_delivery_fee integer check (default_delivery_fee is null or default_delivery_fee between 0 and 100000),
  delivery_delay text check (length(delivery_delay) <= 80),
  min_order integer not null default 0 check (min_order between 0 and 1000000),
  pay_cod boolean not null default true,
  pay_momo boolean not null default false,
  momo_wave text check (length(momo_wave) <= 30),
  momo_orange text check (length(momo_orange) <= 30),
  momo_mtn text check (length(momo_mtn) <= 30),
  momo_moov text check (length(momo_moov) <= 30),
  commission_rate numeric(5,2) not null default 0 check (commission_rate between 0 and 50),
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  check (jsonb_typeof(delivery_fees) = 'object'),
  check (pay_cod or pay_momo)
);

create table if not exists public.products (
  id bigint generated always as identity primary key,
  shop_id bigint not null references public.shops(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 120),
  description text check (length(description) <= 1000),
  category text not null check (category in ('livres','manuels','cahiers','fournitures','documents','annales','autres')),
  level text check (length(level) <= 40),
  subject text check (length(subject) <= 60),
  price integer not null check (price between 0 and 10000000),
  stock integer check (stock is null or stock >= 0),
  photo_url text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists products_shop_idx on public.products (shop_id);

create table if not exists public.orders (
  id bigint generated always as identity primary key,
  ref text not null unique default upper(substr(md5(gen_random_uuid()::text), 1, 6)),
  shop_id bigint not null references public.shops(id) on delete restrict,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  buyer_name text not null,
  buyer_phone text not null,
  delivery_mode text not null check (delivery_mode in ('delivery','pickup')),
  commune text, quartier text, address text,
  subtotal integer not null check (subtotal >= 0),
  delivery_fee integer not null default 0 check (delivery_fee >= 0),
  total integer not null check (total >= 0),
  commission integer not null default 0,
  payment_method text not null check (payment_method in ('cod','momo')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','declared','paid')),
  payment_ref text,
  status text not null default 'new' check (status in ('new','accepted','ready','delivering','delivered','cancelled','refused')),
  note text, seller_note text, cancel_reason text,
  rating smallint check (rating between 1 and 5), review text,
  created_at timestamptz not null default now(),
  accepted_at timestamptz, ready_at timestamptz, delivering_at timestamptz, delivered_at timestamptz, cancelled_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists orders_shop_idx on public.orders (shop_id, created_at desc);
create index if not exists orders_buyer_idx on public.orders (buyer_id, created_at desc);

create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  product_id bigint references public.products(id) on delete set null,
  name text not null,
  unit_price integer not null check (unit_price >= 0),
  qty integer not null check (qty between 1 and 100),
  line_total integer not null
);
create index if not exists order_items_order_idx on public.order_items (order_id);

alter table public.shops enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

grant select on public.shops, public.products to anon, authenticated;
grant insert, update on public.shops to authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.orders, public.order_items to authenticated;

create or replace function public.my_shop_id() returns bigint
language sql stable security definer set search_path = public as $$
  select id from public.shops where owner_id = auth.uid();
$$;
grant execute on function public.my_shop_id() to authenticated;

drop policy if exists "Shops visible" on public.shops;
create policy "Shops visible" on public.shops for select to anon, authenticated
  using (status = 'approved' or owner_id = auth.uid() or public.is_admin());
drop policy if exists "Sellers create own shop" on public.shops;
create policy "Sellers create own shop" on public.shops for insert to authenticated
  with check (owner_id = auth.uid() and status = 'pending'
              and exists (select 1 from public.profiles where id = auth.uid() and role = 'seller'));
drop policy if exists "Sellers update own shop" on public.shops;
create policy "Sellers update own shop" on public.shops for update to authenticated
  using (owner_id = auth.uid() or public.is_admin()) with check (owner_id = auth.uid() or public.is_admin());

-- Le vendeur ne peut pas valider sa boutique ni changer sa commission
create or replace function public.protect_shop() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.status is distinct from old.status or new.commission_rate is distinct from old.commission_rate
       or new.approved_at is distinct from old.approved_at or new.owner_id is distinct from old.owner_id then
      raise exception 'Modification réservée à l’équipe KONE.EDUC';
    end if;
  end if;
  if new.status = 'approved' and old.status is distinct from 'approved' then new.approved_at := now(); end if;
  return new;
end;
$$;
drop trigger if exists protect_shop on public.shops;
create trigger protect_shop before update on public.shops for each row execute function public.protect_shop();

drop policy if exists "Products visible" on public.products;
create policy "Products visible" on public.products for select to anon, authenticated
  using ((active and exists (select 1 from public.shops s where s.id = shop_id and s.status = 'approved'))
         or shop_id = public.my_shop_id() or public.is_admin());
drop policy if exists "Sellers manage own products" on public.products;
create policy "Sellers manage own products" on public.products for all to authenticated
  using (shop_id = public.my_shop_id() or public.is_admin())
  with check (shop_id = public.my_shop_id() or public.is_admin());

create or replace function public.touch_product() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end; $$;
drop trigger if exists touch_product on public.products;
create trigger touch_product before update on public.products for each row execute function public.touch_product();

drop policy if exists "Orders visible to parties" on public.orders;
create policy "Orders visible to parties" on public.orders for select to authenticated
  using (buyer_id = auth.uid() or shop_id = public.my_shop_id() or public.is_admin());
drop policy if exists "Order items visible to parties" on public.order_items;
create policy "Order items visible to parties" on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id
                 and (o.buyer_id = auth.uid() or o.shop_id = public.my_shop_id() or public.is_admin())));

-- Photos des produits et logos : dossier public « shop-images », chacun dans son propre dossier
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shop-images', 'shop-images', true, 3145728, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "Sellers upload shop images" on storage.objects;
drop policy if exists "Sellers update shop images" on storage.objects;
drop policy if exists "Sellers delete shop images" on storage.objects;
create policy "Sellers upload shop images" on storage.objects for insert to authenticated
  with check (bucket_id = 'shop-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Sellers update shop images" on storage.objects for update to authenticated
  using (bucket_id = 'shop-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Sellers delete shop images" on storage.objects for delete to authenticated
  using (bucket_id = 'shop-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- Boutiques publiques avec leur note moyenne et le nombre de commandes livrées
create or replace function public.public_shops()
returns table (id bigint, name text, description text, commune text, quartier text, logo_url text, is_open boolean,
               pickup boolean, delivery_fees jsonb, default_delivery_fee integer, delivery_delay text, min_order integer,
               pay_cod boolean, pay_momo boolean, phone text, whatsapp text, rating numeric, ratings_count bigint, delivered_count bigint, products_count bigint)
language sql stable security definer set search_path = public as $$
  select s.id, s.name, s.description, s.commune, s.quartier, s.logo_url, s.is_open, s.pickup, s.delivery_fees, s.default_delivery_fee,
         s.delivery_delay, s.min_order, s.pay_cod, s.pay_momo, s.phone, s.whatsapp,
         round(avg(o.rating)::numeric, 1), count(o.rating), count(o.id) filter (where o.status = 'delivered'),
         (select count(*) from public.products p where p.shop_id = s.id and p.active)
  from public.shops s left join public.orders o on o.shop_id = s.id
  where s.status = 'approved'
  group by s.id order by count(o.id) filter (where o.status = 'delivered') desc, s.name;
$$;
grant execute on function public.public_shops() to anon, authenticated;

-- Numéros mobile money : visibles seulement par l'acheteur d'une commande payée par mobile money
create or replace function public.order_momo_numbers(p_order bigint)
returns table (wave text, orange text, mtn text, moov text)
language sql stable security definer set search_path = public as $$
  select s.momo_wave, s.momo_orange, s.momo_mtn, s.momo_moov
  from public.orders o join public.shops s on s.id = o.shop_id
  where o.id = p_order and (o.buyer_id = auth.uid() or public.is_admin());
$$;
grant execute on function public.order_momo_numbers(bigint) to authenticated;

-- Passer une commande : prix, stock et frais de livraison calculés par le serveur (jamais par le navigateur)
create or replace function public.place_order(p_shop bigint, p_items jsonb, p_mode text, p_commune text, p_quartier text,
  p_address text, p_payment text, p_name text, p_phone text, p_note text)
returns table (order_id bigint, order_ref text, order_total integer)
language plpgsql security definer set search_path = public as $$
declare v_shop public.shops; v_order public.orders; v_it jsonb; v_p public.products; v_qty integer;
  v_sub integer := 0; v_fee integer := 0; v_lines jsonb := '[]'::jsonb; v_count integer;
begin
  if auth.uid() is null then raise exception 'Connectez-vous pour commander'; end if;
  select * into v_shop from public.shops where id = p_shop;
  if v_shop.id is null or v_shop.status <> 'approved' then raise exception 'Boutique indisponible'; end if;
  if not v_shop.is_open then raise exception 'Cette boutique est fermée pour le moment'; end if;
  if v_shop.owner_id = auth.uid() then raise exception 'Vous ne pouvez pas commander dans votre propre boutique'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'Indiquez votre nom'; end if;
  if length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 8 then raise exception 'Numéro de téléphone invalide'; end if;
  select count(*) into v_count from public.orders where buyer_id = auth.uid() and created_at > now() - interval '1 hour';
  if v_count >= 10 then raise exception 'Trop de commandes en peu de temps. Réessayez plus tard.'; end if;
  if p_payment = 'cod' and not v_shop.pay_cod then raise exception 'Cette boutique n’accepte pas le paiement à la livraison';
  elsif p_payment = 'momo' and not v_shop.pay_momo then raise exception 'Cette boutique n’accepte pas le mobile money';
  elsif p_payment not in ('cod','momo') then raise exception 'Mode de paiement invalide'; end if;
  if p_mode = 'pickup' then
    if not v_shop.pickup then raise exception 'Le retrait en boutique n’est pas proposé'; end if;
  elsif p_mode = 'delivery' then
    if coalesce(trim(p_commune), '') = '' then raise exception 'Indiquez la commune de livraison'; end if;
    if v_shop.delivery_fees ? p_commune then v_fee := (v_shop.delivery_fees ->> p_commune)::integer;
    elsif v_shop.default_delivery_fee is not null then v_fee := v_shop.default_delivery_fee;
    else raise exception 'Cette boutique ne livre pas à %', p_commune; end if;
  else raise exception 'Mode de livraison invalide'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Panier vide'; end if;
  if jsonb_array_length(p_items) > 50 then raise exception 'Trop d’articles différents'; end if;
  for v_it in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_it ->> 'qty')::integer;
    if v_qty is null or v_qty < 1 or v_qty > 100 then raise exception 'Quantité invalide'; end if;
    select * into v_p from public.products where id = (v_it ->> 'product_id')::bigint and shop_id = p_shop for update;
    if v_p.id is null or not v_p.active then raise exception 'Un article n’est plus disponible'; end if;
    if v_p.stock is not null and v_p.stock < v_qty then
      raise exception 'Stock insuffisant pour « % » (reste %)', v_p.name, v_p.stock;
    end if;
    v_sub := v_sub + v_p.price * v_qty;
    v_lines := v_lines || jsonb_build_object('pid', v_p.id, 'name', v_p.name, 'price', v_p.price, 'qty', v_qty);
  end loop;
  if v_sub < v_shop.min_order then raise exception 'Commande minimum : % FCFA', v_shop.min_order; end if;
  insert into public.orders (shop_id, buyer_id, buyer_name, buyer_phone, delivery_mode, commune, quartier, address,
    subtotal, delivery_fee, total, commission, payment_method, note)
  values (p_shop, auth.uid(), left(trim(p_name), 120), left(trim(p_phone), 30), p_mode,
    case when p_mode = 'delivery' then left(trim(p_commune), 80) end, case when p_mode = 'delivery' then left(trim(p_quartier), 80) end,
    case when p_mode = 'delivery' then left(trim(p_address), 200) end,
    v_sub, v_fee, v_sub + v_fee, round(v_sub * v_shop.commission_rate / 100), p_payment, nullif(left(trim(coalesce(p_note, '')), 500), ''))
  returning * into v_order;
  -- Sorties de stock, rattachées à la commande dans le journal des mouvements
  perform set_config('kone.stock_reason', 'vente', true); perform set_config('kone.stock_order', v_order.id::text, true);
  update public.products p set stock = p.stock - (l ->> 'qty')::integer
  from jsonb_array_elements(v_lines) l where p.id = (l ->> 'pid')::bigint and p.stock is not null;
  perform set_config('kone.stock_reason', '', true); perform set_config('kone.stock_order', '', true);
  insert into public.order_items (order_id, product_id, name, unit_price, qty, line_total)
  select v_order.id, (l ->> 'pid')::bigint, l ->> 'name', (l ->> 'price')::integer, (l ->> 'qty')::integer,
         (l ->> 'price')::integer * (l ->> 'qty')::integer
  from jsonb_array_elements(v_lines) l;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_shop.owner_id, '🛒 Nouvelle commande',
    'Commande ' || v_order.ref || ' de ' || v_order.buyer_name || ' : ' || v_order.total || ' FCFA ('
    || case when p_mode = 'pickup' then 'retrait en boutique' else 'livraison à ' || v_order.commune end || '). Acceptez-la vite !',
    'espace-vendeur.html'),
    (auth.uid(), 'Commande envoyée',
    'Votre commande ' || v_order.ref || ' chez ' || v_shop.name || ' (' || v_order.total || ' FCFA) a bien été envoyée. Le vendeur va la confirmer.',
    'mes-commandes.html');
  return query select v_order.id, v_order.ref, v_order.total;
end;
$$;
revoke execute on function public.place_order(bigint, jsonb, text, text, text, text, text, text, text, text) from public;
grant execute on function public.place_order(bigint, jsonb, text, text, text, text, text, text, text, text) to authenticated;

-- Remise en stock des articles d'une commande annulée ou refusée
create or replace function public.restock_order(p_order bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('kone.stock_reason', 'annulation', true); perform set_config('kone.stock_order', p_order::text, true);
  update public.products p set stock = p.stock + i.qty
  from public.order_items i where i.order_id = p_order and i.product_id = p.id and p.stock is not null;
  perform set_config('kone.stock_reason', '', true); perform set_config('kone.stock_order', '', true);
end;
$$;
revoke execute on function public.restock_order(bigint) from public, anon, authenticated;

-- Le vendeur fait avancer la commande : acceptée → prête → en livraison → livrée (ou refusée / annulée)
create or replace function public.seller_update_order(p_order bigint, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_shop public.shops; v_ok boolean; v_msg text;
begin
  select * into v_o from public.orders where id = p_order for update;
  select * into v_shop from public.shops where id = v_o.shop_id;
  if v_o.id is null or (v_shop.owner_id is distinct from auth.uid() and not public.is_admin()) then raise exception 'Commande introuvable'; end if;
  v_ok := case v_o.status
    when 'new' then p_status in ('accepted','refused')
    when 'accepted' then p_status in ('ready','delivering','delivered','cancelled')
    when 'ready' then p_status in ('delivering','delivered','cancelled')
    when 'delivering' then p_status in ('delivered','cancelled')
    else false end;
  if not v_ok then raise exception 'Changement impossible : la commande est déjà « % »', v_o.status; end if;
  if p_status in ('refused','cancelled') and length(trim(coalesce(p_note, ''))) < 3 then
    raise exception 'Indiquez la raison au client';
  end if;
  update public.orders set status = p_status, updated_at = now(),
    seller_note = coalesce(nullif(left(trim(coalesce(p_note, '')), 300), ''), seller_note),
    cancel_reason = case when p_status in ('refused','cancelled') then left(trim(p_note), 300) else cancel_reason end,
    accepted_at = case when p_status = 'accepted' then now() else accepted_at end,
    ready_at = case when p_status = 'ready' then now() else ready_at end,
    delivering_at = case when p_status = 'delivering' then now() else delivering_at end,
    delivered_at = case when p_status = 'delivered' then now() else delivered_at end,
    cancelled_at = case when p_status in ('refused','cancelled') then now() else cancelled_at end,
    payment_status = case when p_status = 'delivered' and payment_method = 'cod' then 'paid' else payment_status end
  where id = p_order;
  if p_status in ('refused','cancelled') then perform public.restock_order(p_order); end if;
  v_msg := case p_status
    when 'accepted' then 'Bonne nouvelle : ' || v_shop.name || ' a accepté votre commande ' || v_o.ref || coalesce(' (' || v_shop.delivery_delay || ')', '') || '.'
    when 'ready' then 'Votre commande ' || v_o.ref || ' est prête' || case when v_o.delivery_mode = 'pickup' then ' : vous pouvez la retirer chez ' || v_shop.name || coalesce(', ' || v_shop.address, '') || '.' else ' et va bientôt partir en livraison.' end
    when 'delivering' then 'Votre commande ' || v_o.ref || ' est en route ! Gardez votre téléphone près de vous.'
    when 'delivered' then 'Commande ' || v_o.ref || ' livrée. Merci ! Donnez une note à ' || v_shop.name || ' pour aider les autres familles.'
    when 'refused' then v_shop.name || ' ne peut pas honorer votre commande ' || v_o.ref || ' : ' || trim(p_note)
    when 'cancelled' then 'Votre commande ' || v_o.ref || ' a été annulée par ' || v_shop.name || ' : ' || trim(p_note) end;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_o.buyer_id, case p_status when 'accepted' then 'Commande acceptée ✅' when 'ready' then 'Commande prête 📦'
    when 'delivering' then 'Commande en route 🛵' when 'delivered' then 'Commande livrée 🎉' else 'Commande annulée' end, v_msg, 'mes-commandes.html');
end;
$$;
revoke execute on function public.seller_update_order(bigint, text, text) from public;
grant execute on function public.seller_update_order(bigint, text, text) to authenticated;

-- Le vendeur confirme avoir reçu le paiement mobile money
create or replace function public.seller_confirm_payment(p_order bigint)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_shop public.shops;
begin
  select * into v_o from public.orders where id = p_order for update;
  select * into v_shop from public.shops where id = v_o.shop_id;
  if v_o.id is null or (v_shop.owner_id is distinct from auth.uid() and not public.is_admin()) then raise exception 'Commande introuvable'; end if;
  if v_o.status in ('refused','cancelled') then raise exception 'Commande annulée'; end if;
  update public.orders set payment_status = 'paid', updated_at = now() where id = p_order;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_o.buyer_id, 'Paiement reçu', v_shop.name || ' confirme la réception de votre paiement pour la commande ' || v_o.ref || '.', 'mes-commandes.html');
end;
$$;
revoke execute on function public.seller_confirm_payment(bigint) from public;
grant execute on function public.seller_confirm_payment(bigint) to authenticated;

-- L'acheteur annule tant que le vendeur n'a pas encore accepté
create or replace function public.buyer_cancel_order(p_order bigint, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_owner uuid;
begin
  select * into v_o from public.orders where id = p_order and buyer_id = auth.uid() for update;
  if v_o.id is null then raise exception 'Commande introuvable'; end if;
  if v_o.status <> 'new' then raise exception 'Le vendeur a déjà accepté la commande : contactez-le pour l’annuler'; end if;
  update public.orders set status = 'cancelled', cancelled_at = now(), updated_at = now(),
    cancel_reason = coalesce(nullif(left(trim(coalesce(p_reason, '')), 300), ''), 'Annulée par le client') where id = p_order;
  perform public.restock_order(p_order);
  select owner_id into v_owner from public.shops where id = v_o.shop_id;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_owner, 'Commande annulée par le client', 'Le client a annulé la commande ' || v_o.ref || coalesce(' : ' || nullif(trim(p_reason), ''), '.'), 'espace-vendeur.html');
end;
$$;
revoke execute on function public.buyer_cancel_order(bigint, text) from public;
grant execute on function public.buyer_cancel_order(bigint, text) to authenticated;

-- L'acheteur signale son paiement mobile money (avec la référence de la transaction)
create or replace function public.buyer_declare_payment(p_order bigint, p_ref text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_owner uuid;
begin
  select * into v_o from public.orders where id = p_order and buyer_id = auth.uid() for update;
  if v_o.id is null then raise exception 'Commande introuvable'; end if;
  if v_o.payment_method <> 'momo' or v_o.payment_status <> 'unpaid' or v_o.status in ('refused','cancelled') then
    raise exception 'Paiement déjà signalé ou commande annulée';
  end if;
  if length(trim(coalesce(p_ref, ''))) < 4 then raise exception 'Indiquez la référence de la transaction'; end if;
  update public.orders set payment_status = 'declared', payment_ref = left(trim(p_ref), 60), updated_at = now() where id = p_order;
  select owner_id into v_owner from public.shops where id = v_o.shop_id;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_owner, 'Paiement à vérifier 💰', 'Le client de la commande ' || v_o.ref || ' dit avoir payé ' || v_o.total || ' FCFA (réf. ' || left(trim(p_ref), 60) || '). Vérifiez puis confirmez.', 'espace-vendeur.html');
end;
$$;
revoke execute on function public.buyer_declare_payment(bigint, text) from public;
grant execute on function public.buyer_declare_payment(bigint, text) to authenticated;

-- L'acheteur confirme la réception (utile si le vendeur oublie de la marquer « livrée »)
create or replace function public.buyer_confirm_received(p_order bigint)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_owner uuid;
begin
  select * into v_o from public.orders where id = p_order and buyer_id = auth.uid() for update;
  if v_o.id is null then raise exception 'Commande introuvable'; end if;
  if v_o.status not in ('accepted','ready','delivering') then raise exception 'Cette commande ne peut pas être confirmée'; end if;
  update public.orders set status = 'delivered', delivered_at = now(), updated_at = now(),
    payment_status = case when payment_method = 'cod' then 'paid' else payment_status end where id = p_order;
  select owner_id into v_owner from public.shops where id = v_o.shop_id;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_owner, 'Commande reçue par le client ✅', 'Le client confirme avoir reçu la commande ' || v_o.ref || '.', 'espace-vendeur.html');
end;
$$;
revoke execute on function public.buyer_confirm_received(bigint) from public;
grant execute on function public.buyer_confirm_received(bigint) to authenticated;

-- Note et avis de l'acheteur, une seule fois après la livraison
create or replace function public.rate_order(p_order bigint, p_rating integer, p_review text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_owner uuid;
begin
  select * into v_o from public.orders where id = p_order and buyer_id = auth.uid() for update;
  if v_o.id is null then raise exception 'Commande introuvable'; end if;
  if v_o.status <> 'delivered' then raise exception 'Vous pourrez noter la boutique après la livraison'; end if;
  if v_o.rating is not null then raise exception 'Vous avez déjà noté cette commande'; end if;
  if p_rating not between 1 and 5 then raise exception 'Note invalide'; end if;
  update public.orders set rating = p_rating, review = nullif(left(trim(coalesce(p_review, '')), 500), ''), updated_at = now() where id = p_order;
  select owner_id into v_owner from public.shops where id = v_o.shop_id;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_owner, 'Nouvel avis ' || repeat('★', p_rating), 'Commande ' || v_o.ref || coalesce(' : « ' || nullif(trim(left(p_review, 200)), '') || ' »', '.'), 'espace-vendeur.html');
end;
$$;
revoke execute on function public.rate_order(bigint, integer, text) from public;
grant execute on function public.rate_order(bigint, integer, text) to authenticated;

-- Derniers avis publics d'une boutique (prénom du client seulement)
create or replace function public.shop_reviews(p_shop bigint)
returns table (rating smallint, review text, buyer text, at timestamptz)
language sql stable security definer set search_path = public as $$
  select o.rating, o.review, split_part(trim(o.buyer_name), ' ', 1), o.delivered_at
  from public.orders o join public.shops s on s.id = o.shop_id
  where o.shop_id = p_shop and s.status = 'approved' and o.rating is not null
  order by o.delivered_at desc nulls last limit 20;
$$;
grant execute on function public.shop_reviews(bigint) to anon, authenticated;

-- Équipe prévenue d'une nouvelle boutique ; vendeur prévenu de la validation
create or replace function public.notify_shop_events() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (recipient_id, title, body, link)
    select a.id, 'Nouvelle boutique à valider', new.name || ' · ' || new.commune || ' · ' || new.phone || '. Vérifiez puis validez.', 'espace-admin.html#shops'
    from public.profiles a where a.role = 'admin';
  elsif new.status is distinct from old.status then
    insert into public.notifications (recipient_id, title, body, link)
    values (new.owner_id,
      case new.status when 'approved' then 'Boutique validée 🎉' when 'suspended' then 'Boutique suspendue' else 'Boutique en attente' end,
      case new.status when 'approved' then 'Votre boutique « ' || new.name || ' » est en ligne : les parents et les enseignants peuvent commander.'
                      when 'suspended' then 'Votre boutique « ' || new.name || ' » est suspendue. Contactez KONE.EDUC sur WhatsApp au 01 61 70 13 61.'
                      else 'Votre boutique est en attente de validation.' end,
      'espace-vendeur.html');
  end if;
  return new;
end;
$$;
drop trigger if exists notify_shop_events on public.shops;
create trigger notify_shop_events after insert or update on public.shops for each row execute function public.notify_shop_events();

do $$ declare t text; begin
  foreach t in array array['shops','products','orders'] loop
    execute format('drop trigger if exists audit_changes on public.%I', t);
    execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function public.audit_changes()', t);
  end loop;
exception when others then raise notice 'Journal de la boutique indisponible (%).', sqlerrm;
end $$;

-- ============================================================
-- Préparations aux examens et concours (CEPE, BEPC, BAC, ENSEA, INPHB…)
-- ============================================================
alter table public.course_requests add column if not exists preparation text check (preparation is null or length(preparation) <= 60);
alter table public.teacher_profiles add column if not exists preparations text check (preparations is null or length(preparations) <= 400);

drop function if exists public.teacher_offers();
create function public.teacher_offers()
returns table (id bigint, subject text, school_level text, location text, format text, availability text,
               created_at timestamptz, request_status text, applicants bigint, my_status text, my_message text, preparation text)
language sql stable security definer set search_path = public as $$
  select r.id, r.subject, r.school_level, r.location, r.format, r.availability, r.created_at, r.status,
         (select count(*) from public.course_applications a where a.course_request_id = r.id),
         mine.status, mine.message, r.preparation
  from public.course_requests r
  left join public.course_applications mine on mine.course_request_id = r.id and mine.teacher_id = auth.uid()
  where public.is_approved_teacher()
    and ((r.status = 'pending' and r.teacher_id is null) or mine.id is not null)
  order by r.created_at desc;
$$;
revoke execute on function public.teacher_offers() from public;
grant execute on function public.teacher_offers() to authenticated;

-- Nouvelle demande : enseignants de la même matière, ou préparant au même examen/concours, prévenus
create or replace function public.notify_new_offer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, title, body)
  select tp.id, 'Nouvelle offre de cours', new.subject || ' · ' || new.school_level || coalesce(' · ' || new.preparation, '') || ' · ' || new.location || '. Postulez depuis « Offres de cours ».'
  from public.teacher_profiles tp join public.profiles p on p.id = tp.id
  where tp.approved and p.role = 'teacher'
    and (lower(trim(tp.subject)) = lower(trim(new.subject))
         or (new.preparation is not null and position(lower(new.preparation) in lower(coalesce(tp.preparations, ''))) > 0));
  return new;
end;
$$;

-- ============================================================
-- Écoles qui cherchent un enseignant qualifié : KONE.EDUC fait la mise en relation
-- ============================================================
create table if not exists public.school_requests (
  id bigint generated always as identity primary key,
  school_name text not null check (length(trim(school_name)) between 2 and 120),
  school_type text check (length(school_type) <= 60),
  contact_name text not null check (length(trim(contact_name)) between 2 and 120),
  phone text not null check (length(trim(phone)) between 8 and 30),
  email text check (length(email) <= 160),
  commune text not null check (length(commune) <= 80),
  quartier text check (length(quartier) <= 80),
  subjects text not null check (length(subjects) <= 300),
  levels text check (length(levels) <= 200),
  preparation text check (length(preparation) <= 60),
  contract text check (contract in ('Vacation','Temps partiel','Temps plein','Remplacement','Cours de soutien')),
  hours_per_week text check (length(hours_per_week) <= 60),
  salary text check (length(salary) <= 80),
  start_date date,
  requirements text check (length(requirements) <= 600),
  details text check (length(details) <= 1000),
  status text not null default 'open' check (status in ('open','matched','closed')),
  matched_teacher_id uuid references public.profiles(id) on delete set null,
  matched_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.school_interests (
  id bigint generated always as identity primary key,
  request_id bigint not null references public.school_requests(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id) on delete cascade,
  message text check (length(message) <= 600),
  created_at timestamptz not null default now(),
  unique (request_id, teacher_id)
);
alter table public.school_requests enable row level security;
alter table public.school_interests enable row level security;
grant select, update, delete on public.school_requests to authenticated;
grant select on public.school_interests to authenticated;
drop policy if exists "Admins manage school requests" on public.school_requests;
create policy "Admins manage school requests" on public.school_requests for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "School interests visible" on public.school_interests;
create policy "School interests visible" on public.school_interests for select to authenticated
  using (teacher_id = auth.uid() or public.is_admin());

-- Dépôt d'une demande par une école, sans compte (limité pour éviter les abus)
create or replace function public.submit_school_request(p_school text, p_type text, p_contact text, p_phone text, p_email text,
  p_commune text, p_quartier text, p_subjects text, p_levels text, p_preparation text, p_contract text, p_hours text,
  p_salary text, p_start date, p_requirements text, p_details text)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint; v_n integer;
begin
  if length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 8 then raise exception 'Numéro de téléphone invalide'; end if;
  if coalesce(trim(p_subjects), '') = '' then raise exception 'Indiquez au moins une matière'; end if;
  select count(*) into v_n from public.school_requests
  where regexp_replace(phone, '\D', '', 'g') = regexp_replace(p_phone, '\D', '', 'g') and created_at > now() - interval '1 day';
  if v_n >= 5 then raise exception 'Trop de demandes aujourd’hui avec ce numéro. Contactez-nous sur WhatsApp au 01 61 70 13 61.'; end if;
  insert into public.school_requests (school_name, school_type, contact_name, phone, email, commune, quartier, subjects, levels,
    preparation, contract, hours_per_week, salary, start_date, requirements, details)
  values (trim(p_school), nullif(trim(coalesce(p_type, '')), ''), trim(p_contact), trim(p_phone), nullif(lower(trim(coalesce(p_email, ''))), ''),
    trim(p_commune), nullif(trim(coalesce(p_quartier, '')), ''), trim(p_subjects), nullif(trim(coalesce(p_levels, '')), ''),
    nullif(trim(coalesce(p_preparation, '')), ''), nullif(p_contract, ''), nullif(trim(coalesce(p_hours, '')), ''), nullif(trim(coalesce(p_salary, '')), ''),
    p_start, nullif(trim(coalesce(p_requirements, '')), ''), nullif(trim(coalesce(p_details, '')), ''))
  returning id into v_id;
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, 'Nouvelle demande d’une école', trim(p_school) || ' (' || trim(p_commune) || ') cherche un enseignant : ' || trim(p_subjects)
    || coalesce(' · ' || nullif(trim(coalesce(p_levels, '')), ''), '') || '. Contact : ' || trim(p_contact) || ' · ' || trim(p_phone) || '.', 'espace-admin.html#schools'
  from public.profiles a where a.role = 'admin';
  -- Les enseignants validés de la matière sont prévenus (sans les coordonnées de l'école)
  insert into public.notifications (recipient_id, title, body, link)
  select tp.id, 'Nouvelle offre d’école', 'Une école à ' || trim(p_commune) || ' cherche un enseignant : ' || trim(p_subjects) || '. Manifestez votre intérêt depuis « Offres de cours ».', 'offres.html'
  from public.teacher_profiles tp join public.profiles p on p.id = tp.id
  where tp.approved and p.role = 'teacher' and position(lower(trim(tp.subject)) in lower(p_subjects)) > 0;
  return v_id;
end;
$$;
revoke execute on function public.submit_school_request(text, text, text, text, text, text, text, text, text, text, text, text, text, date, text, text) from public;
grant execute on function public.submit_school_request(text, text, text, text, text, text, text, text, text, text, text, text, text, date, text, text) to anon, authenticated;

-- Offres des écoles vues par les enseignants validés (sans le nom ni les coordonnées de l'école)
create or replace function public.school_offers()
returns table (id bigint, school_type text, commune text, subjects text, levels text, preparation text, contract text,
               hours_per_week text, salary text, start_date date, requirements text, details text, created_at timestamptz,
               status text, interested bigint, my_interest boolean, matched_me boolean)
language sql stable security definer set search_path = public as $$
  select r.id, r.school_type, r.commune, r.subjects, r.levels, r.preparation, r.contract, r.hours_per_week, r.salary, r.start_date,
         r.requirements, r.details, r.created_at, r.status,
         (select count(*) from public.school_interests i where i.request_id = r.id),
         exists (select 1 from public.school_interests i where i.request_id = r.id and i.teacher_id = auth.uid()),
         r.matched_teacher_id = auth.uid()
  from public.school_requests r
  where public.is_approved_teacher() and (r.status = 'open' or r.matched_teacher_id = auth.uid())
  order by r.created_at desc;
$$;
revoke execute on function public.school_offers() from public;
grant execute on function public.school_offers() to authenticated;

create or replace function public.express_school_interest(p_request bigint, p_message text)
returns void language plpgsql security definer set search_path = public as $$
declare v_r public.school_requests; v_name text;
begin
  if not public.is_approved_teacher() then raise exception 'Réservé aux enseignants validés par KONE.EDUC'; end if;
  select * into v_r from public.school_requests where id = p_request;
  if v_r.id is null or v_r.status <> 'open' then raise exception 'Cette offre n’est plus disponible'; end if;
  insert into public.school_interests (request_id, teacher_id, message)
  values (p_request, auth.uid(), nullif(left(trim(coalesce(p_message, '')), 600), ''))
  on conflict (request_id, teacher_id) do update set message = excluded.message;
  select full_name into v_name from public.profiles where id = auth.uid();
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, 'Enseignant intéressé par une école', coalesce(v_name, 'Un enseignant') || ' est intéressé(e) par l’offre de ' || v_r.school_name || ' (' || v_r.subjects || ').', 'espace-admin.html#schools'
  from public.profiles a where a.role = 'admin';
end;
$$;
revoke execute on function public.express_school_interest(bigint, text) from public;
grant execute on function public.express_school_interest(bigint, text) to authenticated;

-- L'équipe met l'école et l'enseignant choisi en relation : l'enseignant reçoit les coordonnées
create or replace function public.admin_match_school(p_request bigint, p_teacher uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_r public.school_requests;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  select * into v_r from public.school_requests where id = p_request for update;
  if v_r.id is null then raise exception 'Demande introuvable'; end if;
  if not exists (select 1 from public.teacher_profiles tp join public.profiles p on p.id = tp.id where tp.id = p_teacher and tp.approved and p.role = 'teacher') then
    raise exception 'Choisissez un enseignant validé';
  end if;
  update public.school_requests set status = 'matched', matched_teacher_id = p_teacher, matched_at = now() where id = p_request;
  insert into public.notifications (recipient_id, title, body, link)
  values (p_teacher, 'Mise en relation avec une école',
    'KONE.EDUC vous a choisi(e) pour ' || v_r.school_name || ' (' || v_r.commune || ') : ' || v_r.subjects
    || '. Contactez ' || v_r.contact_name || ' au ' || v_r.phone || coalesce(' ou ' || v_r.email, '') || ' de la part de KONE.EDUC.', 'offres.html');
end;
$$;
revoke execute on function public.admin_match_school(bigint, uuid) from public;
grant execute on function public.admin_match_school(bigint, uuid) to authenticated;

-- Offres publiques (sans coordonnées) : page « Offres pour enseignants », partageable et lisible par Google
create or replace function public.public_offers()
returns table (kind text, id bigint, title text, subjects text, levels text, preparation text, commune text, format text, contract text, salary text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select 'cours', r.id, 'Cours à domicile : ' || r.subject || ' (' || r.school_level || ')', r.subject, r.school_level, r.preparation,
         split_part(r.location, ' · ', 1), r.format, null::text, null::text, r.created_at
  from public.course_requests r where r.status = 'pending' and r.teacher_id is null and r.created_at > now() - interval '90 days'
  union all
  select 'ecole', s.id, coalesce(s.school_type, 'École') || ' : enseignant de ' || s.subjects, s.subjects, s.levels, s.preparation,
         s.commune, null, s.contract, s.salary, s.created_at
  from public.school_requests s where s.status = 'open' and s.created_at > now() - interval '120 days'
  order by created_at desc limit 200;
$$;
grant execute on function public.public_offers() to anon, authenticated;

do $$ declare t text; begin
  foreach t in array array['school_requests','school_interests'] loop
    execute format('drop trigger if exists audit_changes on public.%I', t);
    execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function public.audit_changes()', t);
  end loop;
exception when others then raise notice 'Journal des écoles indisponible (%).', sqlerrm;
end $$;

-- ============================================================
-- Boutique : journal de toutes les entrées et sorties de stock
-- ============================================================
create table if not exists public.stock_movements (
  id bigint generated always as identity primary key,
  shop_id bigint references public.shops(id) on delete cascade,
  product_id bigint references public.products(id) on delete set null,
  product_name text,
  delta integer not null,
  stock_after integer,
  reason text not null check (reason in ('creation','vente','annulation','ajustement','suppression')),
  order_id bigint references public.orders(id) on delete set null,
  actor_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists stock_movements_shop_idx on public.stock_movements (shop_id, created_at desc);
alter table public.stock_movements enable row level security;
grant select on public.stock_movements to authenticated;
drop policy if exists "Stock movements visible" on public.stock_movements;
create policy "Stock movements visible" on public.stock_movements for select to authenticated
  using (shop_id = public.my_shop_id() or public.is_admin());

create or replace function public.log_stock_movement() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_reason text := nullif(current_setting('kone.stock_reason', true), ''); v_order bigint := nullif(current_setting('kone.stock_order', true), '')::bigint;
begin
  if tg_op = 'INSERT' then
    if new.stock is not null and new.stock > 0 then
      insert into public.stock_movements (shop_id, product_id, product_name, delta, stock_after, reason, actor_id)
      values (new.shop_id, new.id, new.name, new.stock, new.stock, 'creation', auth.uid());
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if new.stock is distinct from old.stock and new.stock is not null then
      insert into public.stock_movements (shop_id, product_id, product_name, delta, stock_after, reason, order_id, actor_id)
      values (new.shop_id, new.id, new.name, new.stock - coalesce(old.stock, 0), new.stock, coalesce(v_reason, 'ajustement'), v_order, auth.uid());
    end if;
    return new;
  else
    if old.stock is not null and old.stock > 0 and exists (select 1 from public.shops where id = old.shop_id) then
      insert into public.stock_movements (shop_id, product_id, product_name, delta, stock_after, reason, actor_id)
      values (old.shop_id, null, old.name, -old.stock, 0, 'suppression', auth.uid());
    end if;
    return old;
  end if;
end;
$$;
drop trigger if exists log_stock_movement on public.products;
create trigger log_stock_movement after insert or update or delete on public.products
  for each row execute function public.log_stock_movement();

-- ============================================================
-- Ordre et traçabilité : historique conservé, délais automatiques, litiges, contrôle de cohérence
-- ============================================================
-- Les ventes et les factures restent dans l'historique même si un compte est supprimé
do $$ begin
  alter table public.orders drop constraint if exists orders_buyer_id_fkey;
  alter table public.orders alter column buyer_id drop not null;
  alter table public.orders add constraint orders_buyer_id_fkey foreign key (buyer_id) references public.profiles(id) on delete set null;
  alter table public.invoices drop constraint if exists invoices_parent_id_fkey;
  alter table public.invoices alter column parent_id drop not null;
  alter table public.invoices add constraint invoices_parent_id_fkey foreign key (parent_id) references public.profiles(id) on delete set null;
  alter table public.invoices drop constraint if exists invoices_course_request_id_fkey;
  alter table public.invoices alter column course_request_id drop not null;
  alter table public.invoices add constraint invoices_course_request_id_fkey foreign key (course_request_id) references public.course_requests(id) on delete set null;
end $$;

alter table public.orders add column if not exists reminded_at timestamptz;
alter table public.orders add column if not exists auto_closed boolean not null default false;
alter table public.shops add column if not exists terms_accepted_at timestamptz;

-- Litiges ouverts par les clients
create table if not exists public.order_disputes (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  buyer_id uuid references public.profiles(id) on delete set null,
  reason text not null check (reason in ('non_recu','incomplet','different','abime','paiement','autre')),
  message text check (length(message) <= 800),
  status text not null default 'open' check (status in ('open','resolved')),
  resolution text check (length(resolution) <= 800),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index if not exists order_disputes_order_idx on public.order_disputes (order_id);
alter table public.order_disputes enable row level security;
grant select on public.order_disputes to authenticated;
drop policy if exists "Disputes visible to parties" on public.order_disputes;
create policy "Disputes visible to parties" on public.order_disputes for select to authenticated
  using (buyer_id = auth.uid() or public.is_admin()
         or exists (select 1 from public.orders o where o.id = order_id and o.shop_id = public.my_shop_id()));

-- Articles signalés par les utilisateurs
create table if not exists public.product_reports (
  id bigint generated always as identity primary key,
  product_id bigint references public.products(id) on delete set null,
  product_name text,
  shop_id bigint references public.shops(id) on delete cascade,
  reporter_id uuid references public.profiles(id) on delete set null,
  reason text not null check (length(reason) between 3 and 400),
  handled boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.product_reports enable row level security;
grant select, update on public.product_reports to authenticated;
drop policy if exists "Admins manage product reports" on public.product_reports;
create policy "Admins manage product reports" on public.product_reports for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

do $$ declare t text; begin
  foreach t in array array['order_disputes','product_reports'] loop
    execute format('drop trigger if exists audit_changes on public.%I', t);
    execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function public.audit_changes()', t);
  end loop;
exception when others then raise notice 'Journal des litiges indisponible (%).', sqlerrm;
end $$;

create or replace function public.open_dispute(p_order bigint, p_reason text, p_message text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_shop public.shops;
begin
  select * into v_o from public.orders where id = p_order and buyer_id = auth.uid();
  if v_o.id is null then raise exception 'Commande introuvable'; end if;
  if v_o.status in ('new','refused','cancelled') then raise exception 'Cette commande ne peut pas faire l’objet d’un litige'; end if;
  if v_o.status = 'delivered' and coalesce(v_o.delivered_at, v_o.updated_at) < now() - interval '7 days' then
    raise exception 'Le délai de 7 jours après la livraison est dépassé. Contactez KONE.EDUC sur WhatsApp au 01 61 70 13 61.';
  end if;
  if exists (select 1 from public.order_disputes where order_id = p_order and status = 'open') then raise exception 'Un signalement est déjà en cours pour cette commande'; end if;
  insert into public.order_disputes (order_id, buyer_id, reason, message) values (p_order, auth.uid(), p_reason, nullif(left(trim(coalesce(p_message, '')), 800), ''));
  select * into v_shop from public.shops where id = v_o.shop_id;
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, '⚠ Litige boutique', 'Commande ' || v_o.ref || ' chez ' || v_shop.name || ' (' || v_o.total || ' FCFA) : ' || p_reason || coalesce(' – « ' || left(trim(p_message), 200) || ' »', '') || '. À traiter.', 'espace-admin.html#shoplog'
  from public.profiles a where a.role = 'admin';
  insert into public.notifications (recipient_id, title, body, link)
  values (v_shop.owner_id, '⚠ Problème signalé par un client', 'Le client de la commande ' || v_o.ref || ' signale un problème. Contactez-le rapidement ; KONE.EDUC suit le dossier.', 'espace-vendeur.html');
end;
$$;
revoke execute on function public.open_dispute(bigint, text, text) from public;
grant execute on function public.open_dispute(bigint, text, text) to authenticated;

create or replace function public.resolve_dispute(p_dispute bigint, p_resolution text)
returns void language plpgsql security definer set search_path = public as $$
declare v_d public.order_disputes; v_o public.orders; v_owner uuid;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if length(trim(coalesce(p_resolution, ''))) < 3 then raise exception 'Indiquez la décision prise'; end if;
  update public.order_disputes set status = 'resolved', resolution = left(trim(p_resolution), 800), resolved_at = now() where id = p_dispute and status = 'open' returning * into v_d;
  if v_d.id is null then raise exception 'Litige introuvable ou déjà traité'; end if;
  select * into v_o from public.orders where id = v_d.order_id;
  select owner_id into v_owner from public.shops where id = v_o.shop_id;
  insert into public.notifications (recipient_id, title, body, link)
  select x.id, 'Litige traité', 'Commande ' || v_o.ref || ' : ' || trim(p_resolution), x.link
  from (values (v_o.buyer_id, 'mes-commandes.html'), (v_owner, 'espace-vendeur.html')) as x(id, link) where x.id is not null;
end;
$$;
revoke execute on function public.resolve_dispute(bigint, text) from public;
grant execute on function public.resolve_dispute(bigint, text) to authenticated;

create or replace function public.report_product(p_product bigint, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_p public.products; v_n integer;
begin
  if auth.uid() is null then raise exception 'Connectez-vous pour signaler un article'; end if;
  if length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'Expliquez le problème en quelques mots'; end if;
  select count(*) into v_n from public.product_reports where reporter_id = auth.uid() and created_at > now() - interval '1 day';
  if v_n >= 10 then raise exception 'Trop de signalements aujourd’hui'; end if;
  select * into v_p from public.products where id = p_product;
  if v_p.id is null then raise exception 'Article introuvable'; end if;
  insert into public.product_reports (product_id, product_name, shop_id, reporter_id, reason) values (v_p.id, v_p.name, v_p.shop_id, auth.uid(), left(trim(p_reason), 400));
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, 'Article signalé', '« ' || v_p.name || ' » : ' || left(trim(p_reason), 200), 'espace-admin.html#shoplog'
  from public.profiles a where a.role = 'admin';
end;
$$;
revoke execute on function public.report_product(bigint, text) from public;
grant execute on function public.report_product(bigint, text) to authenticated;

-- Délais automatiques (toutes les heures) : rappel à 2 h, annulation à 24 h, clôture des livraisons après 7 jours
create or replace function public.shop_housekeeping() returns integer
language plpgsql security definer set search_path = public as $$
declare r record; v_n integer := 0; v_owner uuid; v_name text;
begin
  for r in select * from public.orders where status = 'new' and reminded_at is null and created_at < now() - interval '2 hours' and created_at >= now() - interval '24 hours' loop
    update public.orders set reminded_at = now() where id = r.id;
    select owner_id into v_owner from public.shops where id = r.shop_id;
    insert into public.notifications (recipient_id, title, body, link)
    values (v_owner, '⏰ Commande en attente', 'La commande ' || r.ref || ' (' || r.total || ' FCFA) attend votre réponse depuis 2 heures. Sans réponse sous 24 h, elle sera annulée automatiquement.', 'espace-vendeur.html');
    v_n := v_n + 1;
  end loop;
  for r in select * from public.orders where status = 'new' and created_at < now() - interval '24 hours' for update skip locked loop
    update public.orders set status = 'cancelled', cancelled_at = now(), updated_at = now(), auto_closed = true,
      cancel_reason = 'Annulée automatiquement : la boutique n’a pas répondu sous 24 heures.' where id = r.id;
    perform public.restock_order(r.id);
    select owner_id, name into v_owner, v_name from public.shops where id = r.shop_id;
    insert into public.notifications (recipient_id, title, body, link)
    select x.id, 'Commande annulée automatiquement', x.body, x.link from (values
      (r.buyer_id, 'Votre commande ' || r.ref || ' chez ' || v_name || ' a été annulée : la boutique n’a pas répondu sous 24 heures. Vous pouvez commander dans une autre boutique.', 'mes-commandes.html'),
      (v_owner, 'La commande ' || r.ref || ' a été annulée automatiquement faute de réponse sous 24 heures. Répondez plus vite pour garder la confiance des clients.', 'espace-vendeur.html')) as x(id, body, link) where x.id is not null;
    v_n := v_n + 1;
  end loop;
  for r in select * from public.orders o where o.status = 'delivering' and o.delivering_at < now() - interval '7 days'
           and not exists (select 1 from public.order_disputes d where d.order_id = o.id and d.status = 'open') for update skip locked loop
    update public.orders set status = 'delivered', delivered_at = now(), updated_at = now(), auto_closed = true,
      payment_status = case when payment_method = 'cod' then 'paid' else payment_status end where id = r.id;
    select owner_id into v_owner from public.shops where id = r.shop_id;
    insert into public.notifications (recipient_id, title, body, link)
    select x.id, 'Commande clôturée', 'La commande ' || r.ref || ' est clôturée comme livrée (aucun problème signalé en 7 jours).', x.link
    from (values (r.buyer_id, 'mes-commandes.html'), (v_owner, 'espace-vendeur.html')) as x(id, link) where x.id is not null;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;
revoke execute on function public.shop_housekeeping() from public, anon, authenticated;

-- Taux des frais de service KONE.EDUC sur la prestation des enseignants : réglage privé (jamais publié)
create or replace function public.admin_fee_rate() returns numeric
language sql stable security definer set search_path = public, private as $$
  select value::numeric from private.settings where key = 'teacher_fee_rate' and public.is_admin();
$$;
revoke execute on function public.admin_fee_rate() from public, anon;
grant execute on function public.admin_fee_rate() to authenticated;
create or replace function public.admin_set_fee_rate(p_rate numeric) returns void
language plpgsql security definer set search_path = public, private as $$
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if p_rate is null or p_rate < 0 or p_rate > 60 then raise exception 'Taux invalide (entre 0 et 60 %%)'; end if;
  insert into private.settings values ('teacher_fee_rate', p_rate::text) on conflict (key) do update set value = excluded.value;
end;
$$;
revoke execute on function public.admin_set_fee_rate(numeric) from public, anon;
grant execute on function public.admin_set_fee_rate(numeric) to authenticated;

-- Contrôle de cohérence : ventes, stocks, factures et versements (selon le taux privé de frais de service)
create or replace function public.integrity_check()
returns table (domaine text, reference text, probleme text)
language plpgsql stable security definer set search_path = public, private as $$
begin
  if auth.uid() is not null and not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  return query
  select 'Boutique', o.ref, 'Total (' || o.total || ') différent des articles + livraison (' || (o.subtotal + o.delivery_fee) || ')' from public.orders o where o.total <> o.subtotal + o.delivery_fee
  union all
  select 'Boutique', o.ref, 'Sous-total (' || o.subtotal || ') différent de la somme des lignes (' || coalesce(s.t, 0) || ')'
  from public.orders o left join (select order_id, sum(line_total) t from public.order_items group by order_id) s on s.order_id = o.id where o.subtotal <> coalesce(s.t, 0)
  union all
  select 'Boutique', o.ref, 'Ligne « ' || i.name || ' » : prix × quantité incorrect' from public.order_items i join public.orders o on o.id = i.order_id where i.line_total <> i.unit_price * i.qty
  union all
  select 'Boutique', o.ref, 'Livrée avec paiement à la livraison mais non marquée payée' from public.orders o where o.status = 'delivered' and o.payment_method = 'cod' and o.payment_status <> 'paid'
  union all
  select 'Boutique', o.ref, 'Commande sans réponse depuis plus de 25 h (l’annulation automatique n’a pas tourné)' from public.orders o where o.status = 'new' and o.created_at < now() - interval '25 hours'
  union all
  select 'Stock', p.name, 'Stock affiché (' || p.stock || ') différent du journal des mouvements (' || m.t || ')'
  from public.products p join (select product_id, sum(delta) t, bool_or(reason = 'creation') c from public.stock_movements group by product_id) m on m.product_id = p.id
  where p.stock is not null and m.c and m.t <> p.stock
  union all
  select 'Litige', o.ref, 'Litige ouvert depuis plus de 3 jours' from public.order_disputes d join public.orders o on o.id = d.order_id where d.status = 'open' and d.created_at < now() - interval '3 days'
  union all
  select 'Cours', cr.student_name || ' (' || cr.subject || ')', 'Cours en cours sans mensualité fixée' from public.course_requests cr where cr.status = 'assigned' and cr.monthly_fee is null
  union all
  select 'Rémunération', cr.student_name || ' (' || cr.subject || ')', 'Enseignant payé ' || tr.monthly_amount || ' F pour ' || cr.monthly_fee || ' F de mensualité (attendu ' || round(cr.monthly_fee * (100 - fr.taux) / 100) || ' F selon le taux de frais de service)'
  from public.teacher_rates tr join public.course_requests cr on cr.id = tr.course_request_id
  cross join (select value::numeric as taux from private.settings where key = 'teacher_fee_rate') fr
  where cr.status = 'assigned' and cr.monthly_fee is not null and abs(tr.monthly_amount - cr.monthly_fee * (100 - fr.taux) / 100) > greatest(100, cr.monthly_fee * 0.01)
  union all
  select 'Versement', tp.teacher_name || ' · ' || to_char(tp.month, 'MM/YYYY'), 'Enseignant payé alors que la mensualité de la famille n’est pas encore encaissée'
  from public.teacher_payouts tp join public.invoices i on i.course_request_id = tp.course_request_id and i.month = tp.month
  where tp.status = 'paid' and i.status <> 'paid'
  union all
  select 'Facture', to_char(i.month, 'MM/YYYY') || ' · ' || i.amount || ' F', 'Facture impayée depuis plus de 15 jours après l’échéance'
  from public.invoices i where i.status = 'unpaid' and i.due_date < current_date - 15;
end;
$$;
revoke execute on function public.integrity_check() from public, anon;
grant execute on function public.integrity_check() to authenticated;

-- Contrôle nocturne : l'équipe est prévenue s'il y a des anomalies
create or replace function public.nightly_integrity() returns integer
language plpgsql security definer set search_path = public as $$
declare v_n integer; v_txt text;
begin
  select count(*), string_agg(domaine || ' ' || reference || ' : ' || probleme, ' · ') into v_n, v_txt from (select * from public.integrity_check() limit 50) x;
  if v_n > 0 then
    insert into public.notifications (recipient_id, title, body, link)
    select a.id, 'Contrôle de cohérence : ' || v_n || ' point(s) à vérifier', left(v_txt, 900), 'espace-admin.html#shoplog'
    from public.profiles a where a.role = 'admin';
  end if;
  return v_n;
end;
$$;
revoke execute on function public.nightly_integrity() from public, anon, authenticated;

do $$ begin
  perform cron.schedule('kone-educ-boutique-delais', '23 * * * *', 'select public.shop_housekeeping()');
  perform cron.schedule('kone-educ-coherence', '41 2 * * *', 'select public.nightly_integrity()');
exception when others then raise notice 'Tâches automatiques indisponibles (pg_cron : %).', sqlerrm;
end $$;

-- ============================================================
-- Offres KONE.EDUC : publiées par l'équipe, visibles par tous, candidatures des enseignants
-- ============================================================
create table if not exists public.job_offers (
  id bigint generated always as identity primary key,
  title text not null check (length(trim(title)) between 3 and 140),
  school_level text check (length(school_level) <= 80),
  subjects text not null check (length(subjects) <= 300),
  preparation text check (length(preparation) <= 60),
  commune text check (length(commune) <= 80),
  quartier text check (length(quartier) <= 80),
  format text check (length(format) <= 60),
  schedule text check (length(schedule) <= 160),
  remuneration text check (length(remuneration) <= 80),
  requirements text check (length(requirements) <= 600),
  details text check (length(details) <= 1500),
  deadline date,
  status text not null default 'open' check (status in ('open','filled','closed')),
  selected_teacher_id uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.job_applications (
  id bigint generated always as identity primary key,
  offer_id bigint not null references public.job_offers(id) on delete cascade,
  teacher_id uuid references public.profiles(id) on delete set null,
  teacher_name text,
  teacher_phone text,
  message text check (length(message) <= 800),
  status text not null default 'pending' check (status in ('pending','accepted','rejected','withdrawn')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (offer_id, teacher_id)
);
alter table public.job_offers enable row level security;
alter table public.job_applications enable row level security;
grant select on public.job_offers to anon, authenticated;
grant insert, update, delete on public.job_offers to authenticated;
grant select on public.job_applications to authenticated;
drop policy if exists "Job offers visible" on public.job_offers;
create policy "Job offers visible" on public.job_offers for select to anon, authenticated using (status <> 'closed' or public.is_admin());
drop policy if exists "Admins manage job offers" on public.job_offers;
create policy "Admins manage job offers" on public.job_offers for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "Job applications visible" on public.job_applications;
create policy "Job applications visible" on public.job_applications for select to authenticated using (teacher_id = auth.uid() or public.is_admin());

create or replace function public.touch_job_offer() returns trigger language plpgsql as $$ begin new.updated_at := now(); return new; end; $$;
drop trigger if exists touch_job_offer on public.job_offers;
create trigger touch_job_offer before update on public.job_offers for each row execute function public.touch_job_offer();

-- Nouvelle offre : tous les comptes Enseignant sont prévenus
create or replace function public.notify_job_offer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'open' then
    insert into public.notifications (recipient_id, title, body, link)
    select p.id, '📢 Nouvelle offre KONE.EDUC', new.title || coalesce(' · ' || new.commune, '') || coalesce(' · ' || new.remuneration, '') || '. Postulez avant qu’elle soit pourvue.', 'offres-enseignants.html#kone-' || new.id
    from public.profiles p where p.role = 'teacher';
  end if;
  return new;
end;
$$;
drop trigger if exists notify_job_offer on public.job_offers;
create trigger notify_job_offer after insert on public.job_offers for each row execute function public.notify_job_offer();

-- Liste publique des offres, avec le nombre de candidats et, pour un enseignant connecté, sa candidature
create or replace function public.public_job_offers()
returns table (id bigint, title text, school_level text, subjects text, preparation text, commune text, quartier text, format text,
               schedule text, remuneration text, requirements text, details text, deadline date, status text, created_at timestamptz,
               applicants bigint, my_status text)
language sql stable security definer set search_path = public as $$
  select o.id, o.title, o.school_level, o.subjects, o.preparation, o.commune, o.quartier, o.format, o.schedule, o.remuneration,
         o.requirements, o.details, o.deadline, o.status, o.created_at,
         (select count(*) from public.job_applications a where a.offer_id = o.id and a.status <> 'withdrawn'),
         (select a.status from public.job_applications a where a.offer_id = o.id and a.teacher_id = auth.uid())
  from public.job_offers o
  where o.status in ('open','filled') and o.created_at > now() - interval '180 days'
  order by (o.status = 'open') desc, o.created_at desc;
$$;
grant execute on function public.public_job_offers() to anon, authenticated;

create or replace function public.apply_job_offer(p_offer bigint, p_message text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.job_offers; v_p public.profiles; v_n integer;
begin
  select * into v_p from public.profiles where id = auth.uid();
  if v_p.id is null or v_p.role <> 'teacher' then raise exception 'Seuls les comptes Enseignant peuvent postuler. Créez un compte Enseignant.'; end if;
  select * into v_o from public.job_offers where id = p_offer;
  if v_o.id is null or v_o.status <> 'open' then raise exception 'Cette offre n’est plus disponible'; end if;
  if v_o.deadline is not null and v_o.deadline < current_date then raise exception 'La date limite de candidature est dépassée'; end if;
  select count(*) into v_n from public.job_applications where teacher_id = auth.uid() and created_at > now() - interval '1 day';
  if v_n >= 20 then raise exception 'Trop de candidatures aujourd’hui'; end if;
  insert into public.job_applications (offer_id, teacher_id, teacher_name, teacher_phone, message)
  values (p_offer, auth.uid(), v_p.full_name, v_p.phone, nullif(left(trim(coalesce(p_message, '')), 800), ''))
  on conflict (offer_id, teacher_id) do update set status = 'pending', message = excluded.message, created_at = now(), decided_at = null
  where public.job_applications.status = 'withdrawn';
  if not found then raise exception 'Vous avez déjà postulé à cette offre'; end if;
  insert into public.notifications (recipient_id, title, body, link)
  select a.id, 'Candidature à une offre KONE.EDUC', coalesce(v_p.full_name, 'Un enseignant') || ' postule à « ' || v_o.title || ' »' || coalesce(' (' || v_p.phone || ')', '') || '.', 'espace-admin.html#joboffers'
  from public.profiles a where a.role = 'admin';
end;
$$;
revoke execute on function public.apply_job_offer(bigint, text) from public;
grant execute on function public.apply_job_offer(bigint, text) to authenticated;

create or replace function public.withdraw_job_application(p_offer bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.job_applications set status = 'withdrawn' where offer_id = p_offer and teacher_id = auth.uid() and status = 'pending';
  if not found then raise exception 'Aucune candidature en cours à retirer'; end if;
end;
$$;
revoke execute on function public.withdraw_job_application(bigint) from public;
grant execute on function public.withdraw_job_application(bigint) to authenticated;

-- L'équipe retient un candidat : l'offre est pourvue, chaque candidat est prévenu
create or replace function public.admin_decide_job_application(p_application bigint, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare v_a public.job_applications; v_o public.job_offers;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs'; end if;
  if p_status not in ('accepted','rejected') then raise exception 'Décision invalide'; end if;
  update public.job_applications set status = p_status, decided_at = now() where id = p_application and status = 'pending' returning * into v_a;
  if v_a.id is null then raise exception 'Candidature introuvable ou déjà traitée'; end if;
  select * into v_o from public.job_offers where id = v_a.offer_id;
  if p_status = 'accepted' then
    update public.job_offers set status = 'filled', selected_teacher_id = v_a.teacher_id where id = v_o.id;
    if v_a.teacher_id is not null then
      insert into public.notifications (recipient_id, title, body, link)
      values (v_a.teacher_id, '🎉 Candidature retenue', 'Vous êtes retenu(e) pour « ' || v_o.title || ' ». L’équipe KONE.EDUC vous contacte pour la suite (fiche d’accord, coordonnées de la famille).', 'offres-enseignants.html#kone-' || v_o.id);
    end if;
    insert into public.notifications (recipient_id, title, body, link)
    select a.teacher_id, 'Offre pourvue', 'L’offre « ' || v_o.title || ' » a été pourvue. Merci pour votre candidature : d’autres offres arrivent bientôt.', 'offres-enseignants.html'
    from public.job_applications a where a.offer_id = v_o.id and a.status = 'pending' and a.teacher_id is not null;
    update public.job_applications set status = 'rejected', decided_at = now() where offer_id = v_o.id and status = 'pending';
  elsif v_a.teacher_id is not null then
    insert into public.notifications (recipient_id, title, body, link)
    values (v_a.teacher_id, 'Candidature non retenue', 'Votre candidature pour « ' || v_o.title || ' » n’a pas été retenue cette fois. Continuez à postuler aux prochaines offres.', 'offres-enseignants.html');
  end if;
end;
$$;
revoke execute on function public.admin_decide_job_application(bigint, text) from public;
grant execute on function public.admin_decide_job_application(bigint, text) to authenticated;

do $$ declare t text; begin
  foreach t in array array['job_offers','job_applications'] loop
    execute format('drop trigger if exists audit_changes on public.%I', t);
    execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function public.audit_changes()', t);
  end loop;
exception when others then raise notice 'Journal des offres indisponible (%).', sqlerrm;
end $$;

-- ============================================================
-- Paiements Wave, Orange Money, MTN MoMo, Moov Money et reçus numérotés
-- ============================================================
-- Les 4 moyens de paiement mobile sont acceptés pour les mensualités (avant : Wave et Orange Money seulement)
do $$ begin
  alter table public.invoices drop constraint if exists invoices_payment_method_check;
  alter table public.invoices add constraint invoices_payment_method_check check (payment_method in ('wave','orange_money','mtn_money','moov_money'));
end $$;
alter table public.orders add column if not exists payment_operator text check (payment_operator in ('wave','orange_money','mtn_money','moov_money'));

-- Reçus : un numéro unique et définitif pour chaque paiement confirmé
create sequence if not exists public.receipt_seq;
create table if not exists public.receipts (
  id bigint generated always as identity primary key,
  number text not null unique,
  kind text not null check (kind in ('mensualite','commande','versement')),
  source_id bigint not null,
  amount integer not null check (amount >= 0),
  method text,
  reference text,
  label text not null,
  payer_name text,
  payee_name text,
  parent_id uuid references public.profiles(id) on delete set null,
  teacher_id uuid references public.profiles(id) on delete set null,
  shop_id bigint references public.shops(id) on delete set null,
  confirmed_by uuid references public.profiles(id) on delete set null,
  issued_at timestamptz not null default now(),
  unique (kind, source_id)
);
create index if not exists receipts_parent_idx on public.receipts (parent_id);
create index if not exists receipts_teacher_idx on public.receipts (teacher_id);
create index if not exists receipts_shop_idx on public.receipts (shop_id);
alter table public.receipts enable row level security;
grant select on public.receipts to authenticated;
drop policy if exists "Receipts visible to parties" on public.receipts;
create policy "Receipts visible to parties" on public.receipts for select to authenticated
  using (public.is_admin() or parent_id = auth.uid() or teacher_id = auth.uid() or (shop_id is not null and shop_id = public.my_shop_id()));

create or replace function public.next_receipt_number() returns text
language sql security definer set search_path = public as $$
  select 'R-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.receipt_seq')::text, 6, '0');
$$;
revoke execute on function public.next_receipt_number() from public, anon, authenticated;

-- Mensualité payée → reçu pour le parent (et l'administration)
create or replace function public.receipt_invoice() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_parent text; v_label text;
begin
  if new.status = 'paid' and (tg_op = 'INSERT' or old.status is distinct from 'paid') then
    select full_name into v_parent from public.profiles where id = new.parent_id;
    select 'Mensualité ' || to_char(new.month, 'MM/YYYY') || coalesce(' – ' || cr.subject || ' (' || cr.student_name || ')', '') into v_label
    from (select 1) x left join public.course_requests cr on cr.id = new.course_request_id;
    insert into public.receipts (number, kind, source_id, amount, method, reference, label, payer_name, payee_name, parent_id, confirmed_by)
    values (public.next_receipt_number(), 'mensualite', new.id, new.amount, new.payment_method, new.payment_reference, v_label, v_parent, 'KONE.EDUC', new.parent_id, auth.uid())
    on conflict (kind, source_id) do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists receipt_invoice on public.invoices;
create trigger receipt_invoice after insert or update of status on public.invoices for each row execute function public.receipt_invoice();

-- Commande payée → reçu pour l'acheteur et le vendeur
create or replace function public.receipt_order() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_shop text;
begin
  if new.payment_status = 'paid' and (tg_op = 'INSERT' or old.payment_status is distinct from 'paid') then
    select name into v_shop from public.shops where id = new.shop_id;
    insert into public.receipts (number, kind, source_id, amount, method, reference, label, payer_name, payee_name, parent_id, shop_id, confirmed_by)
    values (public.next_receipt_number(), 'commande', new.id, new.total,
      case when new.payment_method = 'cod' then coalesce(new.payment_operator, 'livraison') else coalesce(new.payment_operator, 'mobile_money') end,
      new.payment_ref, 'Commande ' || new.ref || ' – ' || coalesce(v_shop, 'boutique'), new.buyer_name, v_shop, new.buyer_id, new.shop_id, auth.uid())
    on conflict (kind, source_id) do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists receipt_order on public.orders;
create trigger receipt_order after insert or update of payment_status on public.orders for each row execute function public.receipt_order();

-- Versement payé à l'enseignant → reçu pour l'enseignant et l'administration
create or replace function public.receipt_payout() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'paid' and (tg_op = 'INSERT' or old.status is distinct from 'paid') then
    insert into public.receipts (number, kind, source_id, amount, method, reference, label, payer_name, payee_name, teacher_id, confirmed_by)
    values (public.next_receipt_number(), 'versement', new.id, new.amount, new.payment_method, new.payment_reference,
      'Versement ' || to_char(new.month, 'MM/YYYY') || ' – ' || new.label, 'KONE.EDUC', new.teacher_name, new.teacher_id, auth.uid())
    on conflict (kind, source_id) do nothing;
  end if;
  return new;
end;
$$;
drop trigger if exists receipt_payout on public.teacher_payouts;
create trigger receipt_payout after insert or update of status on public.teacher_payouts for each row execute function public.receipt_payout();

-- Reçus des paiements déjà confirmés avant cette mise à jour (une seule fois, sans doublon)
insert into public.receipts (number, kind, source_id, amount, method, reference, label, payer_name, payee_name, parent_id, issued_at)
select public.next_receipt_number(), 'mensualite', i.id, i.amount, i.payment_method, i.payment_reference,
       'Mensualité ' || to_char(i.month, 'MM/YYYY'), p.full_name, 'KONE.EDUC', i.parent_id, coalesce(i.paid_at, now())
from public.invoices i left join public.profiles p on p.id = i.parent_id
where i.status = 'paid' and not exists (select 1 from public.receipts r where r.kind = 'mensualite' and r.source_id = i.id);
insert into public.receipts (number, kind, source_id, amount, method, reference, label, payer_name, payee_name, parent_id, shop_id, issued_at)
select public.next_receipt_number(), 'commande', o.id, o.total, case when o.payment_method = 'cod' then 'livraison' else 'mobile_money' end, o.payment_ref,
       'Commande ' || o.ref, o.buyer_name, s.name, o.buyer_id, o.shop_id, coalesce(o.delivered_at, o.updated_at)
from public.orders o join public.shops s on s.id = o.shop_id
where o.payment_status = 'paid' and not exists (select 1 from public.receipts r where r.kind = 'commande' and r.source_id = o.id);
insert into public.receipts (number, kind, source_id, amount, method, reference, label, payer_name, payee_name, teacher_id, issued_at)
select public.next_receipt_number(), 'versement', t.id, t.amount, t.payment_method, t.payment_reference,
       'Versement ' || to_char(t.month, 'MM/YYYY') || ' – ' || t.label, 'KONE.EDUC', t.teacher_name, t.teacher_id, coalesce(t.paid_at, now())
from public.teacher_payouts t
where t.status = 'paid' and not exists (select 1 from public.receipts r where r.kind = 'versement' and r.source_id = t.id);

-- Le vendeur indique l'opérateur utilisé quand il confirme un paiement mobile money
create or replace function public.seller_confirm_payment(p_order bigint, p_operator text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_shop public.shops;
begin
  select * into v_o from public.orders where id = p_order for update;
  select * into v_shop from public.shops where id = v_o.shop_id;
  if v_o.id is null or (v_shop.owner_id is distinct from auth.uid() and not public.is_admin()) then raise exception 'Commande introuvable'; end if;
  if v_o.status in ('refused','cancelled') then raise exception 'Commande annulée'; end if;
  if p_operator is not null and p_operator not in ('wave','orange_money','mtn_money','moov_money') then raise exception 'Opérateur invalide'; end if;
  update public.orders set payment_status = 'paid', payment_operator = coalesce(p_operator, payment_operator), updated_at = now() where id = p_order;
  insert into public.notifications (recipient_id, title, body, link)
  values (v_o.buyer_id, 'Paiement reçu', v_shop.name || ' confirme la réception de votre paiement pour la commande ' || v_o.ref || '. Votre reçu est disponible.', 'mes-commandes.html');
end;
$$;
drop function if exists public.seller_confirm_payment(bigint);
revoke execute on function public.seller_confirm_payment(bigint, text) from public;
grant execute on function public.seller_confirm_payment(bigint, text) to authenticated;

do $$ begin
  drop trigger if exists audit_changes on public.receipts;
  create trigger audit_changes after insert or update or delete on public.receipts for each row execute function public.audit_changes();
exception when others then raise notice 'Journal des reçus indisponible (%).', sqlerrm;
end $$;

-- Recharger la liste des tables de l’API Supabase après les modifications
notify pgrst, 'reload schema';
