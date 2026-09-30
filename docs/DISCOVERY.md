# Discovery and monitoring

The discovery layer is intentionally connector-based. Each connector must operate only on sources where the organization has a lawful basis and where the access/reporting mechanism permits the intended use.

## Flow

```text
Authorized source
      ↓
Discovery connector
      ↓
Discovery job
      ↓
Candidate URL / identifier
      ↓
Canonicalization + deduplication
      ↓
Fingerprint / semantic matching
      ↓
Detection case
      ↓
Human + rights review
```

## Connector requirements

Every connector should provide:
- source name and version
- explicit authorization/terms reference
- rate-limit handling
- timeout and retry policy
- structured error reporting
- canonical URL normalization
- duplicate suppression
- source timestamps
- no credential storage in application tables

Secrets belong in Supabase secrets/Edge Function secrets or a dedicated secret manager, never in `discovery_connectors.configuration`.

## Candidate ≠ infringement

A discovery result is only a candidate. It must pass content matching and rights/evidence review before an enforcement action can be created.

## Safe operating model

Do not implement authentication bypasses, private-group scraping, CAPTCHA circumvention, denial-of-service behavior, stealth collection, or bulk unsupported complaints. Use official APIs, public feeds, authorized integrations, or other permitted mechanisms.
