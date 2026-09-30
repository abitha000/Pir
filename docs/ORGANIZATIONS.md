# Organization & client management

Pir uses a multi-tenant organization model.

## Tenant boundary
Every client/rights-holder organization is represented by one row in `public.organizations`. Users are connected through `public.organization_members`.

## Roles
The role is stored in the membership table and enforced by RLS. Recommended meanings:

- `owner`: full organization administration
- `admin`: team, settings and operational administration
- `analyst`: detection/case operations
- `legal`: rights verification and enforcement review
- `client`: client-facing visibility and approved actions
- `viewer`: read-only access

Use the actual enum values in the Supabase schema as the source of truth.

## Invitations
Invitation tokens must be generated server-side, hashed before storage, have an expiry, and be single-use. Never store raw invitation tokens in Postgres.

An invitation should only grant a role after the recipient authenticates and the server validates the token. Role changes must be audited.

## Recommended onboarding

1. User signs up with Supabase Auth.
2. Create organization.
3. Create owner membership.
4. Complete organization profile.
5. Invite staff/client users.
6. Assign least-privilege roles.
7. Confirm RLS isolation with a second organization.
8. Enable the rights/asset modules.

## Client separation
A rights-holder should only see its own assets, cases, evidence and reports. Internal enforcement/legal users should receive access only to organizations explicitly assigned to them.
