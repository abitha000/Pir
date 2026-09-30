-- Commit 004: rights and asset management

create type public.asset_type as enum ('film','series','episode','music','image','book','software','other');
create type public.right_status as enum ('pending','verified','expired','revoked');

create table if not exists public.copyright_assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  asset_type public.asset_type not null default 'film',
  external_id text,
  release_at timestamptz,
  runtime_seconds integer,
  language text,
  country_of_origin text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rights_records (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.copyright_assets(id) on delete cascade,
  rights_holder_name text not null,
  rights_type text not null,
  territory text not null default '*',
  starts_at timestamptz,
  ends_at timestamptz,
  status public.right_status not null default 'pending',
  authorization_reference text,
  evidence_storage_key text,
  notes text,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.asset_references (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.copyright_assets(id) on delete cascade,
  reference_type text not null,
  storage_key text not null,
  sha256 text not null check (sha256 ~ '^[0-9a-fA-F]{64}$'),
  size_bytes bigint,
  mime_type text,
  duration_seconds numeric,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists copyright_assets_org_idx on public.copyright_assets(organization_id);
create index if not exists copyright_assets_title_idx on public.copyright_assets using gin (to_tsvector('simple', title));
create index if not exists rights_records_asset_idx on public.rights_records(asset_id);
create index if not exists asset_references_asset_idx on public.asset_references(asset_id);

alter table public.copyright_assets enable row level security;
alter table public.rights_records enable row level security;
alter table public.asset_references enable row level security;

create policy copyright_assets_member_select on public.copyright_assets
for select to authenticated using (public.is_org_member(organization_id));

create policy copyright_assets_ops_insert on public.copyright_assets
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
  and created_by = auth.uid()
);

create policy copyright_assets_ops_update on public.copyright_assets
for update to authenticated using (public.has_org_role(organization_id, array['owner','admin','analyst','legal']))
with check (public.has_org_role(organization_id, array['owner','admin','analyst','legal']));

create policy copyright_assets_admin_delete on public.copyright_assets
for delete to authenticated using (public.has_org_role(organization_id, array['owner','admin']));

create policy rights_records_member_select on public.rights_records
for select to authenticated using (
  exists (select 1 from public.copyright_assets a where a.id = asset_id and public.is_org_member(a.organization_id))
);

create policy rights_records_legal_insert on public.rights_records
for insert to authenticated with check (
  exists (select 1 from public.copyright_assets a where a.id = asset_id and public.has_org_role(a.organization_id, array['owner','admin','legal']))
);

create policy rights_records_legal_update on public.rights_records
for update to authenticated using (
  exists (select 1 from public.copyright_assets a where a.id = asset_id and public.has_org_role(a.organization_id, array['owner','admin','legal']))
) with check (
  exists (select 1 from public.copyright_assets a where a.id = asset_id and public.has_org_role(a.organization_id, array['owner','admin','legal']))
);

create policy asset_references_member_select on public.asset_references
for select to authenticated using (
  exists (select 1 from public.copyright_assets a where a.id = asset_id and public.is_org_member(a.organization_id))
);

create policy asset_references_ops_insert on public.asset_references
for insert to authenticated with check (
  exists (select 1 from public.copyright_assets a where a.id = asset_id and public.has_org_role(a.organization_id, array['owner','admin','analyst','legal']))
  and created_by = auth.uid()
);

comment on table public.rights_records is 'Chain-of-rights records used to establish whether an organization is authorized to enforce an asset.';
comment on table public.asset_references is 'Immutable reference artifacts used by downstream fingerprinting/detection pipelines.';
