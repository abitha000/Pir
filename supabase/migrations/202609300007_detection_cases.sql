-- Commit 007: detection case management

create type public.case_status as enum ('detected','triage','rights_review','evidence_review','notice_ready','submitted','platform_pending','removed','rejected','disputed','closed');
create type public.severity_level as enum ('low','medium','high','critical');

create table if not exists public.detection_cases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  asset_id uuid not null references public.copyright_assets(id) on delete restrict,
  source text not null,
  source_url text not null,
  source_identifier text,
  status public.case_status not null default 'detected',
  severity public.severity_level not null default 'medium',
  confidence numeric(5,2) not null default 0 check (confidence >= 0 and confidence <= 100),
  match_method text,
  match_score numeric(8,5),
  detected_at timestamptz not null default now(),
  last_verified_at timestamptz,
  assigned_to uuid references auth.users(id),
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.case_events (
  id bigint generated always as identity primary key,
  case_id uuid not null references public.detection_cases(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  event_type text not null,
  from_status public.case_status,
  to_status public.case_status,
  actor_user_id uuid references auth.users(id),
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.case_evidence (
  case_id uuid not null references public.detection_cases(id) on delete cascade,
  evidence_id uuid not null references public.evidence_items(id) on delete restrict,
  relation text not null default 'supporting',
  created_at timestamptz not null default now(),
  primary key (case_id, evidence_id)
);

create index if not exists detection_cases_org_status_idx on public.detection_cases(organization_id,status,severity,detected_at desc);
create index if not exists detection_cases_asset_idx on public.detection_cases(asset_id);
create index if not exists detection_cases_assignee_idx on public.detection_cases(assigned_to,status);
create index if not exists detection_cases_source_idx on public.detection_cases(source);
create index if not exists case_events_case_idx on public.case_events(case_id,created_at);

alter table public.detection_cases enable row level security;
alter table public.case_events enable row level security;
alter table public.case_evidence enable row level security;

create policy detection_cases_member_select on public.detection_cases
for select to authenticated using (public.is_org_member(organization_id));

create policy detection_cases_ops_insert on public.detection_cases
for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','analyst','legal']));

create policy detection_cases_ops_update on public.detection_cases
for update to authenticated using (public.has_org_role(organization_id,array['owner','admin','analyst','legal']))
with check (public.has_org_role(organization_id,array['owner','admin','analyst','legal']));

create policy case_events_member_select on public.case_events
for select to authenticated using (public.is_org_member(organization_id));

create policy case_events_ops_insert on public.case_events
for insert to authenticated with check (public.has_org_role(organization_id,array['owner','admin','analyst','legal']));

create policy case_evidence_member_select on public.case_evidence
for select to authenticated using (
  exists(select 1 from public.detection_cases c where c.id=case_id and public.is_org_member(c.organization_id))
);

create policy case_evidence_ops_insert on public.case_evidence
for insert to authenticated with check (
  exists(select 1 from public.detection_cases c where c.id=case_id and public.has_org_role(c.organization_id,array['owner','admin','analyst','legal']))
);

comment on table public.detection_cases is 'Potential infringement detections requiring triage, rights verification and evidence review before enforcement.';
comment on table public.case_events is 'Append-oriented operational history for case workflow transitions.';
