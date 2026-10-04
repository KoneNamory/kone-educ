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
drop policy if exists "Teachers create own profile" on public.teacher_profiles;
create policy "Teachers create own profile" on public.teacher_profiles for insert to authenticated
  with check (auth.uid() = id and approved = false);
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
  with check (auth.uid() = parent_id and teacher_id is null and status = 'pending');

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
  check (payment_method in ('wave','orange_money','moov_money')) not valid;

-- L'administrateur voit le nom et le téléphone des parents et des enseignants pour les contacter
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

-- Recharger la liste des tables de l’API Supabase après les modifications
notify pgrst, 'reload schema';
