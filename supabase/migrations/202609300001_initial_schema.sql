-- RightsGuard / Pir initial Supabase schema
create extension if not exists vector;

create type public.member_role as enum ('owner','admin','legal','analyst','viewer');
create type public.asset_type as enum ('film','series','episode','music','music_video','book','image','software','other');
create type public.rights_status as enum ('pending','verified','expired','revoked');
create type public.case_status as enum ('detected','review','rights_verified','evidence_locked','notice_ready','submitted','platform_pending','removed','rejected','disputed','escalated','closed');
create type public.evidence_kind as enum ('screenshot','html','metadata','image','video','audio','document','hash','other');
create type public.action_status as enum ('queued','legal_review','approved','submitted','acknowledged','removed','rejected','failed','cancelled');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.member_role not null default 'viewer',
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  asset_type public.asset_type not null default 'film',
  release_date date,
  rights_status public.rights_status not null default 'pending',
  rights_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.asset_references (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id) on delete cascade,
  kind text not null,
  storage_path text,
  sha256 text,
  embedding vector(3072),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.cases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_id uuid not null references public.assets(id) on delete cascade,
  source text not null,
  source_url text not null,
  status public.case_status not null default 'detected',
  confidence numeric(5,2) not null default 0 check (confidence >= 0 and confidence <= 100),
  description text not null default '',
  first_detected_at timestamptz not null default now(),
  last_checked_at timestamptz,
  removal_verified boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.evidence (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  kind public.evidence_kind not null,
  storage_path text,
  sha256 text not null,
  captured_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table public.enforcement_actions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases(id) on delete cascade,
  platform text not null,
  action_type text not null,
  status public.action_status not null default 'queued',
  external_reference text,
  submitted_at timestamptz,
  response_at timestamptz,
  response_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index cases_org_status_idx on public.cases(organization_id, status);
create index cases_asset_idx on public.cases(asset_id);
create index evidence_case_idx on public.evidence(case_id);
create index actions_case_idx on public.enforcement_actions(case_id);

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.assets enable row level security;
alter table public.asset_references enable row level security;
alter table public.cases enable row level security;
alter table public.evidence enable row level security;
alter table public.enforcement_actions enable row level security;
alter table public.audit_logs enable row level security;

create or replace function public.is_org_member(org_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.organization_members m where m.organization_id = org_id and m.user_id = auth.uid());
$$;

create policy org_member_read on public.organizations for select using (public.is_org_member(id));
create policy member_read on public.organization_members for select using (user_id = auth.uid() or public.is_org_member(organization_id));
create policy assets_member_all on public.assets for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy refs_member_all on public.asset_references for all using (exists(select 1 from public.assets a where a.id = asset_id and public.is_org_member(a.organization_id))) with check (exists(select 1 from public.assets a where a.id = asset_id and public.is_org_member(a.organization_id)));
create policy cases_member_all on public.cases for all using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy evidence_member_all on public.evidence for all using (exists(select 1 from public.cases c where c.id = case_id and public.is_org_member(c.organization_id))) with check (exists(select 1 from public.cases c where c.id = case_id and public.is_org_member(c.organization_id)));
create policy actions_member_all on public.enforcement_actions for all using (exists(select 1 from public.cases c where c.id = case_id and public.is_org_member(c.organization_id))) with check (exists(select 1 from public.cases c where c.id = case_id and public.is_org_member(c.organization_id)));
create policy audit_member_read on public.audit_logs for select using (public.is_org_member(organization_id));
