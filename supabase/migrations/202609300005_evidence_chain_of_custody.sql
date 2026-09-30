-- Commit 005: evidence and chain-of-custody foundation

create type public.evidence_status as enum ('captured','verified','quarantined','invalidated');

create table if not exists public.evidence_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_id uuid references public.copyright_assets(id) on delete set null,
  case_id uuid,
  evidence_type text not null,
  source_url text,
  captured_at timestamptz not null,
  captured_by uuid references auth.users(id),
  storage_key text not null,
  sha256 text not null check (sha256 ~ '^[0-9a-fA-F]{64}$'),
  size_bytes bigint,
  mime_type text,
  status public.evidence_status not null default 'captured',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists evidence_org_idx on public.evidence_items(organization_id);
create index if not exists evidence_asset_idx on public.evidence_items(asset_id);
create index if not exists evidence_case_idx on public.evidence_items(case_id);
create index if not exists evidence_sha_idx on public.evidence_items(sha256);

alter table public.evidence_items enable row level security;

create policy evidence_member_select on public.evidence_items
for select to authenticated
using (public.is_org_member(organization_id));

create policy evidence_ops_insert on public.evidence_items
for insert to authenticated
with check (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
  and captured_by = auth.uid()
);

create policy evidence_legal_update on public.evidence_items
for update to authenticated
using (public.has_org_role(organization_id, array['owner','admin','legal']))
with check (public.has_org_role(organization_id, array['owner','admin','legal']));

-- Append-only custody events. No UPDATE/DELETE policies are intentionally provided.
create table if not exists public.evidence_custody_events (
  id bigint generated always as identity primary key,
  evidence_id uuid not null references public.evidence_items(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid references auth.users(id),
  occurred_at timestamptz not null default now(),
  sha256_before text,
  sha256_after text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists evidence_custody_evidence_idx on public.evidence_custody_events(evidence_id, occurred_at);
create index if not exists evidence_custody_org_idx on public.evidence_custody_events(organization_id);

alter table public.evidence_custody_events enable row level security;

create policy custody_member_select on public.evidence_custody_events
for select to authenticated
using (public.is_org_member(organization_id));

create policy custody_ops_insert on public.evidence_custody_events
for insert to authenticated
with check (
  public.has_org_role(organization_id, array['owner','admin','analyst','legal'])
  and actor_user_id = auth.uid()
);

-- Public clients must not be able to mutate evidence custody history.
comment on table public.evidence_custody_events is 'Append-only chain-of-custody events. Do not expose update/delete operations to application roles.';
comment on column public.evidence_items.sha256 is 'Cryptographic integrity hash of the exact stored evidence object.';
