-- Commit 008: lawful discovery and monitoring infrastructure
-- This schema stores connector configuration and candidate observations.
-- Connectors must use authorized/public/API-permitted sources and respect
-- service terms, rate limits, privacy requirements and reporting rules.

create type public.discovery_job_status as enum ('queued','running','completed','failed','cancelled');
create type public.discovery_candidate_status as enum ('new','deduplicated','queued_for_match','matched','not_a_match','review');

create table if not exists public.discovery_connectors (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  connector_type text not null,
  enabled boolean not null default false,
  configuration jsonb not null default '{}'::jsonb,
  last_run_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.discovery_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  connector_id uuid not null references public.discovery_connectors(id) on delete cascade,
  asset_id uuid references public.copyright_assets(id) on delete set null,
  status public.discovery_job_status not null default 'queued',
  scheduled_for timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  attempts integer not null default 0,
  result_count integer not null default 0,
  error_message text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.discovery_candidates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  job_id uuid references public.discovery_jobs(id) on delete set null,
  asset_id uuid references public.copyright_assets(id) on delete set null,
  source text not null,
  source_url text not null,
  source_identifier text,
  canonical_url text,
  title text,
  discovered_at timestamptz not null default now(),
  candidate_status public.discovery_candidate_status not null default 'new',
  content_hash text,
  metadata jsonb not null default '{}'::jsonb,
  unique (organization_id, source, source_url)
);

create index if not exists discovery_connectors_org_idx on public.discovery_connectors(organization_id);
create index if not exists discovery_jobs_status_idx on public.discovery_jobs(organization_id,status,scheduled_for);
create index if not exists discovery_candidates_asset_idx on public.discovery_candidates(asset_id,candidate_status);
create index if not exists discovery_candidates_hash_idx on public.discovery_candidates(content_hash);

alter table public.discovery_connectors enable row level security;
alter table public.discovery_jobs enable row level security;
alter table public.discovery_candidates enable row level security;

create policy discovery_connectors_member_select on public.discovery_connectors
for select to authenticated using (public.is_org_member(organization_id));

create policy discovery_connectors_admin_write on public.discovery_connectors
for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin']));

create policy discovery_connectors_admin_update on public.discovery_connectors
for update to authenticated using (public.has_org_role(organization_id,array['owner','admin']))
with check (public.has_org_role(organization_id,array['owner','admin']));

create policy discovery_jobs_member_select on public.discovery_jobs
for select to authenticated using (public.is_org_member(organization_id));

create policy discovery_jobs_ops_insert on public.discovery_jobs
for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','analyst']));

create policy discovery_jobs_ops_update on public.discovery_jobs
for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','analyst']))
with check (public.has_org_role(organization_id,array['owner','admin','analyst']));

create policy discovery_candidates_member_select on public.discovery_candidates
for select to authenticated using (public.is_org_member(organization_id));

create policy discovery_candidates_ops_insert on public.discovery_candidates
for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','analyst']));

create policy discovery_candidates_ops_update on public.discovery_candidates
for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','analyst']))
with check (public.has_org_role(organization_id,array['owner','admin','analyst']));

comment on table public.discovery_connectors is 'Configuration for authorized/public discovery sources. Credentials must be stored outside this table in a secret manager.';
comment on table public.discovery_candidates is 'Potential matches discovered from permitted sources; candidates are not infringement findings until verified.';
