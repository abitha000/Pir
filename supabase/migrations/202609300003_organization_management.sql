-- Commit 003: organization/client management foundation
-- Organizations are tenants. Membership is the authorization boundary.

create table if not exists public.organization_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email text not null,
  role public.organization_role not null default 'viewer',
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id, email, accepted_at)
);

create index if not exists organization_invitations_org_idx
  on public.organization_invitations(organization_id);
create index if not exists organization_invitations_email_idx
  on public.organization_invitations(lower(email));

alter table public.organization_invitations enable row level security;

drop policy if exists invitations_admin_select on public.organization_invitations;
create policy invitations_admin_select on public.organization_invitations
  for select to authenticated
  using (public.has_org_role(organization_id, array['owner','admin']));

drop policy if exists invitations_admin_insert on public.organization_invitations;
create policy invitations_admin_insert on public.organization_invitations
  for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','admin']) and invited_by = auth.uid());

drop policy if exists invitations_admin_update on public.organization_invitations;
create policy invitations_admin_update on public.organization_invitations
  for update to authenticated
  using (public.has_org_role(organization_id, array['owner','admin']))
  with check (public.has_org_role(organization_id, array['owner','admin']));

drop policy if exists invitations_admin_delete on public.organization_invitations;
create policy invitations_admin_delete on public.organization_invitations
  for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','admin']));

-- Safe helper for displaying a user's organization memberships.
create or replace view public.my_organizations
with (security_invoker = true)
as
select
  m.organization_id,
  m.user_id,
  m.role,
  m.status,
  o.name,
  o.created_at
from public.organization_members m
join public.organizations o on o.id = m.organization_id
where m.user_id = auth.uid();

-- Organization profile updates are restricted to owner/admin.
drop policy if exists organizations_member_select on public.organizations;
create policy organizations_member_select on public.organizations
  for select to authenticated
  using (public.is_org_member(id));

drop policy if exists organizations_admin_update on public.organizations;
create policy organizations_admin_update on public.organizations
  for update to authenticated
  using (public.has_org_role(id, array['owner','admin']))
  with check (public.has_org_role(id, array['owner','admin']));

comment on table public.organization_invitations is 'Pending invitations for tenant membership. Store only a hash of invitation tokens.';
