-- SuperDental LP Manager - Supabase schema
-- Execute este arquivo no SQL Editor do Supabase.
-- Depois, crie os usuarios em Authentication > Users com os mesmos e-mails
-- cadastrados em public.profiles.

create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('admin', 'midia');
  end if;

  if not exists (select 1 from pg_type where typname = 'lp_status') then
    create type public.lp_status as enum ('ativo', 'inativo');
  end if;
end $$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique,
  nome text not null,
  email text not null unique,
  role public.app_role not null default 'midia',
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  nome_divulgacao text not null,
  nome_contato text not null default '',
  whatsapp text not null default '',
  endereco text not null default '',
  google_tag_manager text not null default '',
  sellbot boolean not null default false,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.clients
  add column if not exists google_tag_manager text not null default '';

create table if not exists public.landing_pages (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clients(id) on delete cascade,
  nome text not null,
  status public.lp_status not null default 'ativo',
  link text not null default '',
  frase_whatsapp text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clients_nome_idx on public.clients using gin (to_tsvector('portuguese', nome || ' ' || nome_divulgacao));
create unique index if not exists clients_nome_divulgacao_unique_idx on public.clients (nome_divulgacao);
create index if not exists landing_pages_cliente_id_idx on public.landing_pages (cliente_id);
create unique index if not exists landing_pages_cliente_nome_unique_idx on public.landing_pages (cliente_id, nome);
create index if not exists landing_pages_status_idx on public.landing_pages (status);
create index if not exists landing_pages_created_at_idx on public.landing_pages (created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_clients_updated_at on public.clients;
create trigger set_clients_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

drop trigger if exists set_landing_pages_updated_at on public.landing_pages;
create trigger set_landing_pages_updated_at
before update on public.landing_pages
for each row execute function public.set_updated_at();

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.ativo = true
      and (
        p.auth_user_id = auth.uid()
        or lower(p.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.ativo = true
      and p.role = 'admin'
      and (
        p.auth_user_id = auth.uid()
        or lower(p.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      )
  );
$$;

create or replace function public.guard_landing_page_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.cliente_id is distinct from old.cliente_id
    or new.nome is distinct from old.nome
    or new.link is distinct from old.link
    or new.frase_whatsapp is distinct from old.frase_whatsapp
    or new.created_at is distinct from old.created_at then
    raise exception 'Somente administradores podem editar campos da landing page alem do status.';
  end if;

  return new;
end;
$$;

drop trigger if exists guard_landing_page_update on public.landing_pages;
create trigger guard_landing_page_update
before update on public.landing_pages
for each row execute function public.guard_landing_page_update();

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.landing_pages enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles for select
to authenticated
using (public.is_active_user());

drop policy if exists "profiles_insert_admin" on public.profiles;
create policy "profiles_insert_admin"
on public.profiles for insert
to authenticated
with check (public.is_admin());

drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin"
on public.profiles for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "profiles_delete_admin" on public.profiles;
create policy "profiles_delete_admin"
on public.profiles for delete
to authenticated
using (public.is_admin());

drop policy if exists "clients_select_active_users" on public.clients;
create policy "clients_select_active_users"
on public.clients for select
to authenticated
using (public.is_active_user());

drop policy if exists "clients_insert_admin" on public.clients;
create policy "clients_insert_admin"
on public.clients for insert
to authenticated
with check (public.is_admin());

drop policy if exists "clients_update_admin" on public.clients;
create policy "clients_update_admin"
on public.clients for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "clients_delete_admin" on public.clients;
create policy "clients_delete_admin"
on public.clients for delete
to authenticated
using (public.is_admin());

drop policy if exists "landing_pages_select_active_users" on public.landing_pages;
create policy "landing_pages_select_active_users"
on public.landing_pages for select
to authenticated
using (public.is_active_user());

drop policy if exists "landing_pages_insert_admin" on public.landing_pages;
create policy "landing_pages_insert_admin"
on public.landing_pages for insert
to authenticated
with check (public.is_admin());

drop policy if exists "landing_pages_update_authenticated" on public.landing_pages;
create policy "landing_pages_update_authenticated"
on public.landing_pages for update
to authenticated
using (public.is_active_user())
with check (public.is_active_user());

drop policy if exists "landing_pages_delete_admin" on public.landing_pages;
create policy "landing_pages_delete_admin"
on public.landing_pages for delete
to authenticated
using (public.is_admin());

-- Seed inicial. Troque os e-mails conforme sua equipe antes de rodar em producao.
insert into public.profiles (nome, email, role, ativo) values
  ('Denis Diniz', 'denis.diniz@saludigital.com.br', 'admin', true),
  ('Ana Souza', 'ana.souza@superdental.com.br', 'midia', true),
  ('Carlos Lima', 'carlos.lima@superdental.com.br', 'midia', false)
on conflict (email) do update set
  nome = excluded.nome,
  role = excluded.role,
  ativo = excluded.ativo;

with seed_clients as (
  insert into public.clients (nome, nome_divulgacao, nome_contato, whatsapp, endereco, sellbot, ativo, created_at) values
    ('Sorriso Premium Odontologia', 'Sorriso Premium', 'Fernanda Alves', '(11) 98765-4321', 'Av. Paulista, 1000 - Sao Paulo/SP', true, true, '2026-07-20'),
    ('OdontoVida Clinica Integrada', 'OdontoVida', 'Marcos Ribeiro', '(21) 99876-5432', 'Rua das Flores, 45 - Rio de Janeiro/RJ', false, true, '2026-07-25'),
    ('Clinica Dental Excellence', 'Dental Excellence', 'Juliana Costa', '(31) 99123-4567', 'Av. Afonso Pena, 300 - Belo Horizonte/MG', true, true, '2026-08-02'),
    ('Bright Smile Odontologia', 'Bright Smile', 'Rafael Souza', '(41) 98811-2233', 'Rua XV de Novembro, 220 - Curitiba/PR', false, false, '2026-08-10'),
    ('OrtoCenter Especialidades', 'OrtoCenter', 'Patricia Nunes', '(51) 99654-3210', 'Av. Ipiranga, 500 - Porto Alegre/RS', true, true, '2026-08-18'),
    ('Clinica Vitale Odonto', 'Vitale Odonto', 'Bruno Martins', '(61) 99345-6789', 'SQN 210 - Brasilia/DF', false, true, '2026-08-25')
  on conflict do nothing
  returning id, nome_divulgacao
)
insert into public.landing_pages (cliente_id, nome, status, link, frase_whatsapp, created_at)
select c.id, lp.nome, lp.status::public.lp_status, lp.link, lp.frase_whatsapp, lp.created_at::timestamptz
from public.clients c
join (values
  ('Sorriso Premium', 'LP Implante Dentario', 'ativo', 'https://sorrisopremium.superdental.lp/implante', 'Ola! Quero agendar uma avaliacao de implante dentario.', '2026-07-22'),
  ('Sorriso Premium', 'LP Clareamento Dental', 'ativo', 'https://sorrisopremium.superdental.lp/clareamento', 'Ola! Quero saber mais sobre clareamento dental.', '2026-08-05'),
  ('OdontoVida', 'LP Ortodontia Invisivel', 'ativo', 'https://odontovida.superdental.lp/ortodontia', 'Ola! Quero informacoes sobre ortodontia invisivel.', '2026-07-28'),
  ('OdontoVida', 'LP Avaliacao Gratuita', 'inativo', 'https://odontovida.superdental.lp/avaliacao', 'Ola! Quero agendar minha avaliacao gratuita.', '2026-08-12'),
  ('Dental Excellence', 'LP Facetas de Porcelana', 'ativo', 'https://dentalexcellence.superdental.lp/facetas', 'Ola! Quero saber mais sobre facetas de porcelana.', '2026-08-04'),
  ('Dental Excellence', 'LP Emergencia Odontologica', 'ativo', 'https://dentalexcellence.superdental.lp/emergencia', 'Ola! Preciso de atendimento de emergencia.', '2026-08-19'),
  ('Bright Smile', 'LP Implante Dentario', 'inativo', 'https://brightsmile.superdental.lp/implante', 'Ola! Quero avaliacao para implante.', '2026-08-11'),
  ('OrtoCenter', 'LP Aparelho Ortodontico', 'ativo', 'https://ortocenter.superdental.lp/aparelho', 'Ola! Quero orcamento de aparelho ortodontico.', '2026-08-20'),
  ('OrtoCenter', 'LP Invisalign', 'ativo', 'https://ortocenter.superdental.lp/invisalign', 'Ola! Quero saber sobre o Invisalign.', '2026-09-01'),
  ('Vitale Odonto', 'LP Odontologia Estetica', 'ativo', 'https://vitaleodonto.superdental.lp/estetica', 'Ola! Quero saber sobre odontologia estetica.', '2026-08-27'),
  ('Vitale Odonto', 'LP Canal e Restauracao', 'ativo', 'https://vitaleodonto.superdental.lp/canal', 'Ola! Preciso agendar canal/restauracao.', '2026-09-08'),
  ('Sorriso Premium', 'LP Protese Dentaria', 'ativo', 'https://sorrisopremium.superdental.lp/protese', 'Ola! Quero informacoes sobre protese dentaria.', '2026-09-10')
) as lp(cliente, nome, status, link, frase_whatsapp, created_at)
  on c.nome_divulgacao = lp.cliente
where not exists (
  select 1
  from public.landing_pages existing
  where existing.cliente_id = c.id
    and existing.nome = lp.nome
);
