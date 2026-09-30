-- Commit 006: content fingerprinting and embedding infrastructure
-- pgvector is used only for semantic/reference embeddings. Binary/audio/video
-- fingerprints remain separate because their comparison characteristics differ.

create extension if not exists vector with schema extensions;

create type public.fingerprint_kind as enum ('audio','video','image','text','semantic');
create type public.processing_status as enum ('queued','processing','completed','failed','cancelled');

create table if not exists public.fingerprint_models (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  version text not null,
  kind public.fingerprint_kind not null,
  dimensions integer,
  provider text,
  model_identifier text,
  configuration jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(name, version)
);

create table if not exists public.fingerprint_jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_id uuid not null references public.copyright_assets(id) on delete cascade,
  reference_id uuid references public.asset_references(id) on delete set null,
  model_id uuid not null references public.fingerprint_models(id),
  status public.processing_status not null default 'queued',
  priority integer not null default 100,
  attempts integer not null default 0,
  error_message text,
  started_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists fingerprint_jobs_org_status_idx on public.fingerprint_jobs(organization_id,status,priority);
create index if not exists fingerprint_jobs_asset_idx on public.fingerprint_jobs(asset_id);

create table if not exists public.content_fingerprints (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_id uuid not null references public.copyright_assets(id) on delete cascade,
  reference_id uuid references public.asset_references(id) on delete set null,
  model_id uuid not null references public.fingerprint_models(id),
  kind public.fingerprint_kind not null,
  algorithm text not null,
  fingerprint text,
  vector_data vector(3072),
  segment_start_ms bigint,
  segment_end_ms bigint,
  checksum text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists content_fingerprints_asset_idx on public.content_fingerprints(asset_id);
create index if not exists content_fingerprints_model_idx on public.content_fingerprints(model_id);
create index if not exists content_fingerprints_checksum_idx on public.content_fingerprints(checksum);

-- HNSW is appropriate for semantic vector retrieval once enough vectors exist.
create index if not exists content_fingerprints_vector_hnsw_idx
on public.content_fingerprints using hnsw (vector_data vector_cosine_ops)
where vector_data is not null;

alter table public.fingerprint_models enable row level security;
alter table public.fingerprint_jobs enable row level security;
alter table public.content_fingerprints enable row level security;

create policy fingerprint_models_authenticated_select on public.fingerprint_models
for select to authenticated using (true);

create policy fingerprint_jobs_member_select on public.fingerprint_jobs
for select to authenticated using (public.is_org_member(organization_id));

create policy fingerprint_jobs_ops_insert on public.fingerprint_jobs
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
);

create policy fingerprint_jobs_ops_update on public.fingerprint_jobs
for update to authenticated using (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
) with check (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
);

create policy content_fingerprints_member_select on public.content_fingerprints
for select to authenticated using (public.is_org_member(organization_id));

create policy content_fingerprints_ops_insert on public.content_fingerprints
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
);

comment on table public.fingerprint_models is 'Versioned fingerprint/embedding model registry. Model changes must be versioned, not overwritten.';
comment on table public.fingerprint_jobs is 'Asynchronous reference fingerprint generation jobs.';
comment on table public.content_fingerprints is 'Reference fingerprints used by downstream lawful matching/detection systems.';
