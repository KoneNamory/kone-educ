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

-- À l'inscription, seuls les rôles Parent et Enseignant peuvent être choisis
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles for insert to authenticated
  with check (auth.uid() = id and role in ('parent','teacher'));

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
  if p_role not in ('parent', 'teacher') then raise exception 'Type de compte invalide'; end if;
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
create or replace function public.teacher_offers()
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
  if p_role not in ('parent','teacher') then raise exception 'Type de compte invalide'; end if;
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
    || '<p style="margin:24px 0"><a href="https://kone-educ.vercel.app/connexion.html" style="background:#1559eb;color:#fff;padding:12px 18px;border-radius:10px;text-decoration:none;font-weight:700">Ouvrir mon espace</a></p>'
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
    when v_role = 'teacher' then 'espace-enseignant.html'
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
  select a.id, 'Nouvel inscrit', coalesce(new.full_name, 'Un utilisateur') || ' vient de créer un compte ' || case new.role when 'teacher' then 'Enseignant' else 'Parent' end || coalesce(' · ' || new.phone, '') || '.'
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

-- Recharger la liste des tables de l’API Supabase après les modifications
notify pgrst, 'reload schema';
