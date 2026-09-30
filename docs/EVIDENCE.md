# Evidence and chain of custody

Every enforcement case should be backed by evidence that can be traced to an exact stored object.

## Evidence record

An evidence item records:
- organization and optional asset/case
- evidence type
- source URL
- capture timestamp
- authenticated operator
- private storage key
- SHA-256 hash
- MIME type and size
- current evidence status
- structured capture metadata

## Custody

`evidence_custody_events` is append-only for application roles. A custody event should be created whenever evidence is captured, verified, transferred, quarantined, invalidated, or otherwise materially handled.

A recommended sequence is:

`captured → hash_calculated → stored → verified → submitted → rechecked`

If a file is transformed for analysis, preserve the original object and create a separate derived evidence object. Never overwrite the original evidence object.

## Storage

Evidence should live in a private Supabase Storage bucket. Store only the storage key in Postgres. Use short-lived signed URLs for authorized viewing.

For high-value evidence, use object-lock/WORM-capable archival storage in addition to Supabase Storage, according to the client's retention requirements.

## Security

- Do not expose the service-role key to the browser.
- Do not make the evidence bucket public.
- Scan uploaded files before analyst access.
- Restrict evidence access by organization and role.
- Log access to sensitive evidence.
- Preserve original timestamps and source metadata.
- Keep the exact original object immutable.
