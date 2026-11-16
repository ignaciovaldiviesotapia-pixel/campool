-- Campool · base de datos (Supabase / PostgreSQL)
-- Pegá este archivo completo en Supabase → SQL Editor → Run. Se puede volver a correr sin romper nada.

-- ============ Comunidades ============
create table if not exists public.orgs (
  id text primary key,
  name text not null,
  join_code text not null,            -- código que se le pasa a la gente para entrar
  email_domain text,                  -- si el mail termina así, entra sin código (ej. itba.edu.ar)
  auto_approve boolean not null default true  -- false: aunque tenga código, espera a un administrador
);
insert into public.orgs (id, name, join_code, email_domain) values
  ('itba', 'ITBA', 'ITBA-2026', 'itba.edu.ar'),
  ('ww', 'WeWork Vicente López', 'WEWORK-2026', null)
on conflict (id) do nothing;

-- ============ Personas ============
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  org_id text not null references public.orgs,
  name text not null check (char_length(name) between 2 and 60),
  about text not null default '' check (char_length(about) <= 80),
  status text not null default 'pending' check (status in ('pending','approved','blocked')),
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now()
);

-- ============ Viajes que ofrece un conductor ============
create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  org_id text not null references public.orgs,
  driver_id uuid not null default auth.uid() references public.profiles on delete cascade,
  sede text not null,
  days int[] not null,                -- 1 = lunes ... 6 = sábado
  depart text not null,               -- hora de salida, "07:30"
  back text not null default '',
  zone_name text not null default '',
  zone_lat double precision not null, -- centro de la zona de 2 cuadras, ya corrido: nunca la dirección
  zone_lng double precision not null,
  seats int not null check (seats between 1 and 6),
  car text not null default '',
  kml numeric not null check (kml between 3 and 40),
  repeat boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============ Pedidos de quien busca viaje ============
create table if not exists public.seeks (
  id uuid primary key default gen_random_uuid(),
  org_id text not null references public.orgs,
  user_id uuid not null default auth.uid() references public.profiles on delete cascade,
  sede text not null,
  days int[] not null,
  arrive text not null,
  back text not null default '',
  zone_name text not null default '',
  zone_lat double precision not null,
  zone_lng double precision not null,
  repeat boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============ Solicitudes de lugar ============
create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips on delete cascade,
  passenger_id uuid not null default auth.uid() references public.profiles on delete cascade,
  dow int not null check (dow between 1 and 6),
  day_label text not null default '',
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  meet text not null default '' check (char_length(meet) <= 200),  -- punto de encuentro: lo escribe el conductor al aceptar
  est_share numeric not null default 0,
  est_saved numeric not null default 0,
  est_km numeric not null default 0,
  created_at timestamptz not null default now(),
  unique (trip_id, passenger_id, dow)
);

-- ============ Viajes en curso compartidos en vivo ============
-- Quien participa de un viaje puede compartirlo mientras dura. El link lleva una clave larga al azar:
-- cualquiera que lo tenga ve el recorrido, sin cuenta. Se apaga solo al terminar.
create table if not exists public.live_trips (
  id uuid primary key default gen_random_uuid(),
  token text not null unique check (char_length(token) between 20 and 64),
  trip_id uuid not null references public.trips on delete cascade,
  started_by uuid not null default auth.uid() references public.profiles on delete cascade,
  label text not null default '' check (char_length(label) <= 160),
  dest_name text not null default '' check (char_length(dest_name) <= 80),
  dest_lat double precision,
  dest_lng double precision,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  last_lat double precision,
  last_lng double precision,
  last_at timestamptz,
  trail jsonb not null default '[]'::jsonb
);

-- ============ Preferencias del viaje y viajes solo entre mujeres ============
alter table public.profiles add column if not exists gender text check (gender in ('f','m','x'));   -- opcional, lo declara cada persona al registrarse
alter table public.trips add column if not exists prefs text[] not null default '{}';
alter table public.trips add column if not exists women_only boolean not null default false;

-- ============ Avisos (por ejemplo: "cancelaron tu viaje") ============
create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles on delete cascade,
  kind text not null,
  body text not null default '',
  sede text,
  dow int,
  created_at timestamptz not null default now()
);

-- ============ Chat entre conductor y pasajero aceptado ============
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.requests on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

-- ============ Reportes a quien administra ============
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  org_id text not null references public.orgs,
  reporter_id uuid not null references public.profiles on delete cascade,
  target_id uuid not null references public.profiles on delete cascade,
  reason text not null check (char_length(reason) between 3 and 300),
  created_at timestamptz not null default now()
);

-- ============ Calificaciones después del viaje ============
-- Conductor y pasajero de una solicitud aceptada se califican entre sí con 1 a 5 estrellas. Una por persona y por viaje.
create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  org_id text not null references public.orgs,
  rater_id uuid not null references public.profiles on delete cascade,
  ratee_id uuid not null references public.profiles on delete cascade,
  stars int not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  unique (request_id, rater_id)
);

-- ============ Funciones de apoyo ============
-- Versión del esquema: la app la consulta para saber qué funciones están disponibles.
create or replace function public.schema_version() returns int language sql immutable as $$ select 4 $$;

create or replace function public.my_gender() returns text
language sql stable security definer set search_path = public as $$
  select gender from public.profiles where id = auth.uid()
$$;

create or replace function public.my_org() returns text
language sql stable security definer set search_path = public as $$
  select org_id from public.profiles where id = auth.uid() and status = 'approved'
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and status = 'approved')
$$;

-- Al registrarse alguien se crea su perfil. Entra aprobado si es la primera persona de la comunidad
-- (queda como administradora), si su mail es del dominio de la comunidad o si trae el código correcto.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  o public.orgs%rowtype;
  first_one boolean;
  ok boolean;
begin
  select * into o from public.orgs where id = m->>'org';
  if not found then raise exception 'Comunidad desconocida'; end if;
  select not exists (select 1 from public.profiles where org_id = o.id and role = 'admin') into first_one;
  ok := first_one
     or (o.email_domain is not null and lower(new.email) like '%@' || lower(o.email_domain))
     or (o.auto_approve and upper(trim(coalesce(m->>'code', ''))) = upper(o.join_code));
  insert into public.profiles (id, org_id, name, about, status, role, gender)
  values (new.id, o.id, left(trim(coalesce(nullif(m->>'name', ''), 'Sin nombre')), 60), left(trim(coalesce(m->>'about', '')), 80),
          case when ok then 'approved' else 'pending' end, case when first_one then 'admin' else 'member' end,
          case when m->>'gender' in ('f','m','x') then m->>'gender' end);
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Un administrador aprueba o bloquea a alguien de su comunidad.
create or replace function public.approve_member(uid uuid, ok boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Solo un administrador puede hacer esto'; end if;
  update public.profiles set status = case when ok then 'approved' else 'blocked' end
   where id = uid and org_id = public.my_org() and role <> 'admin';
end $$;

-- El código de la comunidad, solo para administradores (para pasárselo a la gente).
create or replace function public.org_code() returns text
language sql stable security definer set search_path = public as $$
  select o.join_code from public.orgs o where o.id = public.my_org() and public.is_admin()
$$;

-- Lugares ya ocupados por viaje y día, sin revelar quiénes son.
create or replace function public.taken_counts() returns table (trip_id uuid, dow int, n int)
language sql stable security definer set search_path = public as $$
  select r.trip_id, r.dow, count(*)::int from public.requests r
    join public.trips t on t.id = r.trip_id
   where r.status = 'accepted' and t.org_id = public.my_org()
   group by r.trip_id, r.dow
$$;

-- El conductor acepta o rechaza una solicitud; al aceptar escribe el punto de encuentro.
create or replace function public.respond_request(req uuid, accept boolean, meet_text text default '') returns void
language plpgsql security definer set search_path = public as $$
declare r public.requests%rowtype; t public.trips%rowtype; used int;
begin
  select * into r from public.requests where id = req;
  if not found then raise exception 'La solicitud no existe'; end if;
  select * into t from public.trips where id = r.trip_id;
  if t.driver_id <> auth.uid() then raise exception 'Solo el conductor puede responder'; end if;
  if accept then
    select count(*) into used from public.requests where trip_id = r.trip_id and dow = r.dow and status = 'accepted' and id <> r.id;
    if used >= t.seats then raise exception 'Ya no quedan lugares para ese día'; end if;
    update public.requests set status = 'accepted', meet = left(coalesce(meet_text, ''), 200) where id = req;
  else
    update public.requests set status = 'rejected' where id = req;
  end if;
end $$;

-- Quien pidió el lugar puede retirar su solicitud (se borra, así puede volver a pedir más adelante).
create or replace function public.cancel_request(req uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r public.requests%rowtype; t public.trips%rowtype;
begin
  select * into r from public.requests where id = req and passenger_id = auth.uid();
  if not found then return; end if;
  if r.status = 'accepted' then
    select * into t from public.trips where id = r.trip_id;
    insert into public.notices (user_id, kind, body, sede, dow)
    values (t.driver_id, 'seat_cancelled', coalesce((select split_part(name, ' ', 1) from public.profiles where id = r.passenger_id), 'Alguien')
            || ' canceló su lugar del ' || r.day_label || '.', t.sede, r.dow);
  end if;
  delete from public.requests where id = r.id;
end $$;

-- Plan B: si un conductor borra un viaje, cada persona que tenía lugar pedido o aceptado recibe un aviso.
create or replace function public.trip_deleted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notices (user_id, kind, body, sede, dow)
  select r.passenger_id, 'trip_cancelled',
         coalesce((select split_part(name, ' ', 1) from public.profiles where id = old.driver_id), 'El conductor')
         || ' canceló el viaje de las ' || old.depart || ' (' || r.day_label || ').', old.sede, r.dow
    from public.requests r where r.trip_id = old.id and r.status in ('pending', 'accepted');
  return old;
end $$;
drop trigger if exists on_trip_deleted on public.trips;
create trigger on_trip_deleted before delete on public.trips for each row execute function public.trip_deleted();

-- ¿Puedo chatear en esta solicitud? Solo el conductor y la persona aceptada.
create or replace function public.can_chat(req uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.requests r join public.trips t on t.id = r.trip_id
                  where r.id = req and r.status = 'accepted' and (r.passenger_id = auth.uid() or t.driver_id = auth.uid()))
$$;

-- Reportar a alguien de mi comunidad: lo ve solo quien administra.
create or replace function public.report_user(target uuid, why text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_org() is null then raise exception 'Tu cuenta no está aprobada'; end if;
  if target = auth.uid() then raise exception 'No podés reportarte'; end if;
  if not exists (select 1 from public.profiles where id = target and org_id = public.my_org()) then raise exception 'Esa persona no es de tu comunidad'; end if;
  insert into public.reports (org_id, reporter_id, target_id, reason) values (public.my_org(), auth.uid(), target, left(trim(why), 300));
end $$;

-- Números de la comunidad, solo para quien administra.
create or replace function public.org_stats() returns table (members int, trips int, seeks int, accepted int, km numeric, saved numeric)
language sql stable security definer set search_path = public as $$
  select (select count(*)::int from public.profiles where org_id = public.my_org() and status = 'approved'),
         (select count(*)::int from public.trips where org_id = public.my_org()),
         (select count(*)::int from public.seeks where org_id = public.my_org()),
         (select count(*)::int from public.requests r join public.trips t on t.id = r.trip_id where t.org_id = public.my_org() and r.status = 'accepted'),
         (select coalesce(sum(r.est_km), 0) from public.requests r join public.trips t on t.id = r.trip_id where t.org_id = public.my_org() and r.status = 'accepted'),
         (select coalesce(sum(r.est_saved), 0) from public.requests r join public.trips t on t.id = r.trip_id where t.org_id = public.my_org() and r.status = 'accepted')
   where public.is_admin()
$$;

-- Guarda la posición actual de un viaje en curso (solo quien lo inició). Conserva los últimos 400 puntos.
create or replace function public.live_ping(lid uuid, lat double precision, lng double precision) returns void
language plpgsql security definer set search_path = public as $$
begin
  if lat is null or lng is null or lat not between -90 and 90 or lng not between -180 and 180 then return; end if;
  -- Si el auto está quieto se actualiza la hora pero no se repite el punto en el recorrido.
  update public.live_trips
     set last_lat = lat, last_lng = lng, last_at = now(),
         trail = case when trail -> -1 = jsonb_build_array(round(lat::numeric, 5), round(lng::numeric, 5)) then trail
                      else (case when jsonb_array_length(trail) >= 400 then trail - 0 else trail end)
                           || jsonb_build_array(jsonb_build_array(round(lat::numeric, 5), round(lng::numeric, 5))) end
   where id = lid and started_by = auth.uid() and ended_at is null;
end $$;

create or replace function public.live_end(lid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.live_trips set ended_at = now() where id = lid and started_by = auth.uid() and ended_at is null;
end $$;

-- Lo que ve cualquiera que tenga el link. Deja de responder 8 horas después de iniciado o 30 minutos después de finalizado.
create or replace function public.live_view(tok text)
returns table (label text, dest_name text, dest_lat double precision, dest_lng double precision, started_at timestamptz,
               ended_at timestamptz, last_lat double precision, last_lng double precision, last_at timestamptz, trail jsonb)
language sql stable security definer set search_path = public as $$
  select l.label, l.dest_name, l.dest_lat, l.dest_lng, l.started_at, l.ended_at, l.last_lat, l.last_lng, l.last_at, l.trail
    from public.live_trips l
   where l.token = tok and char_length(tok) >= 20
     and l.started_at > now() - interval '8 hours'
     and (l.ended_at is null or l.ended_at > now() - interval '30 minutes')
$$;

-- Califica a la otra persona de una solicitud aceptada. Si ya había calificado, actualiza.
create or replace function public.rate(req uuid, stars_given int) returns void
language plpgsql security definer set search_path = public as $$
declare r public.requests%rowtype; t public.trips%rowtype; other uuid;
begin
  if stars_given is null or stars_given not between 1 and 5 then raise exception 'La calificación va de 1 a 5'; end if;
  select * into r from public.requests where id = req and status = 'accepted';
  if not found then raise exception 'Solo se califican viajes aceptados'; end if;
  select * into t from public.trips where id = r.trip_id;
  if auth.uid() = r.passenger_id then other := t.driver_id;
  elsif auth.uid() = t.driver_id then other := r.passenger_id;
  else raise exception 'No participaste de este viaje'; end if;
  insert into public.ratings (request_id, org_id, rater_id, ratee_id, stars) values (req, t.org_id, auth.uid(), other, stars_given)
  on conflict (request_id, rater_id) do update set stars = excluded.stars, created_at = now();
end $$;

-- Promedio y cantidad de calificaciones de cada persona de mi comunidad (sin decir quién puso qué).
create or replace function public.ratings_summary() returns table (user_id uuid, avg numeric, n int)
language sql stable security definer set search_path = public as $$
  select g.ratee_id, round(avg(g.stars)::numeric, 1), count(*)::int from public.ratings g
   where g.org_id = public.my_org() group by g.ratee_id
$$;

-- ============ Reglas de acceso (cada quien ve solo su comunidad) ============
alter table public.orgs enable row level security;      -- sin políticas: nadie lee los códigos desde la app
alter table public.profiles enable row level security;
alter table public.trips enable row level security;
alter table public.seeks enable row level security;
alter table public.requests enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or (org_id = public.my_org() and (status = 'approved' or public.is_admin())));
drop policy if exists profiles_edit on public.profiles;
create policy profiles_edit on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (name, about) on public.profiles to authenticated;   -- nadie puede aprobarse solo ni cambiarse de comunidad

drop policy if exists trips_read on public.trips;
create policy trips_read on public.trips for select to authenticated using (org_id = public.my_org());
drop policy if exists trips_add on public.trips;
create policy trips_add on public.trips for insert to authenticated
  with check (driver_id = auth.uid() and org_id = public.my_org()
              and prefs <@ array['musica','silencio','mascotas','equipaje','sin_humo']::text[]
              and (not women_only or public.my_gender() = 'f'));
drop policy if exists trips_del on public.trips;
create policy trips_del on public.trips for delete to authenticated using (driver_id = auth.uid());
revoke update on public.trips from anon, authenticated;

drop policy if exists seeks_read on public.seeks;
create policy seeks_read on public.seeks for select to authenticated using (org_id = public.my_org());
drop policy if exists seeks_add on public.seeks;
create policy seeks_add on public.seeks for insert to authenticated with check (user_id = auth.uid() and org_id = public.my_org());
drop policy if exists seeks_del on public.seeks;
create policy seeks_del on public.seeks for delete to authenticated using (user_id = auth.uid());
revoke update on public.seeks from anon, authenticated;

drop policy if exists requests_read on public.requests;
create policy requests_read on public.requests for select to authenticated
  using (passenger_id = auth.uid() or exists (select 1 from public.trips t where t.id = trip_id and t.driver_id = auth.uid()));
drop policy if exists requests_add on public.requests;
create policy requests_add on public.requests for insert to authenticated
  with check (passenger_id = auth.uid() and status = 'pending' and meet = ''
              and exists (select 1 from public.trips t where t.id = trip_id and t.org_id = public.my_org() and t.driver_id <> auth.uid()
                             and (not t.women_only or public.my_gender() = 'f')));
revoke update, delete on public.requests from anon, authenticated;   -- se responde y se cancela solo con las funciones de arriba

alter table public.live_trips enable row level security;
drop policy if exists live_read on public.live_trips;
create policy live_read on public.live_trips for select to authenticated
  using (started_by = auth.uid()
         or exists (select 1 from public.trips t where t.id = live_trips.trip_id and t.driver_id = auth.uid())
         or exists (select 1 from public.requests r where r.trip_id = live_trips.trip_id and r.passenger_id = auth.uid() and r.status = 'accepted'));
drop policy if exists live_add on public.live_trips;
create policy live_add on public.live_trips for insert to authenticated
  with check (started_by = auth.uid() and ended_at is null and last_at is null
              and (exists (select 1 from public.trips t where t.id = live_trips.trip_id and t.driver_id = auth.uid())
                   or exists (select 1 from public.requests r where r.trip_id = live_trips.trip_id and r.passenger_id = auth.uid() and r.status = 'accepted')));
revoke update, delete on public.live_trips from anon, authenticated;   -- la posición se guarda solo con live_ping

alter table public.notices enable row level security;
drop policy if exists notices_read on public.notices;
create policy notices_read on public.notices for select to authenticated using (user_id = auth.uid());
drop policy if exists notices_del on public.notices;
create policy notices_del on public.notices for delete to authenticated using (user_id = auth.uid());
revoke insert, update on public.notices from anon, authenticated;

alter table public.messages enable row level security;
drop policy if exists messages_read on public.messages;
create policy messages_read on public.messages for select to authenticated using (public.can_chat(request_id));
drop policy if exists messages_add on public.messages;
create policy messages_add on public.messages for insert to authenticated with check (sender_id = auth.uid() and public.can_chat(request_id));
revoke update, delete on public.messages from anon, authenticated;

alter table public.reports enable row level security;
drop policy if exists reports_read on public.reports;
create policy reports_read on public.reports for select to authenticated using (public.is_admin() and org_id = public.my_org());
drop policy if exists reports_del on public.reports;
create policy reports_del on public.reports for delete to authenticated using (public.is_admin() and org_id = public.my_org());
revoke insert, update on public.reports from anon, authenticated;

alter table public.ratings enable row level security;
drop policy if exists ratings_read_own on public.ratings;
create policy ratings_read_own on public.ratings for select to authenticated using (rater_id = auth.uid());   -- cada quien ve solo las que puso
revoke insert, update, delete on public.ratings from anon, authenticated;                                    -- se califica solo con rate()

revoke all on public.orgs, public.profiles, public.trips, public.seeks, public.requests, public.live_trips, public.ratings, public.notices, public.messages, public.reports from anon;
revoke execute on function public.report_user(uuid, text), public.org_stats(), public.can_chat(uuid) from public, anon;
grant execute on function public.report_user(uuid, text), public.org_stats(), public.can_chat(uuid), public.my_gender() to authenticated;
revoke execute on function public.rate(uuid, int), public.ratings_summary() from public, anon;
grant execute on function public.rate(uuid, int), public.ratings_summary(), public.schema_version() to authenticated;
revoke execute on function public.live_ping(uuid, double precision, double precision), public.live_end(uuid) from public, anon;
grant execute on function public.live_ping(uuid, double precision, double precision), public.live_end(uuid) to authenticated;
grant execute on function public.live_view(text) to anon, authenticated;   -- el link público
revoke execute on function public.approve_member(uuid, boolean), public.org_code(), public.taken_counts(),
  public.respond_request(uuid, boolean, text), public.cancel_request(uuid) from public, anon;
grant execute on function public.approve_member(uuid, boolean), public.org_code(), public.taken_counts(),
  public.respond_request(uuid, boolean, text), public.cancel_request(uuid) to authenticated;

-- ============ Avisos en vivo ============
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.trips; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.seeks; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.requests; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.profiles; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.live_trips; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.notices; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
  end if;
end $$;
