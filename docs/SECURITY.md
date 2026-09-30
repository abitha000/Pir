# Security baseline

- Never store service-role keys in the browser.
- All client-visible data must be protected by Supabase RLS.
- Evidence objects should use private Storage buckets and short-lived signed URLs.
- Keep an immutable audit trail for enforcement actions.
- Require verified rights/authorization before a complaint can reach `approved` or `submitted`.
- Treat external content as untrusted input; scan uploads and sanitize rendered HTML.
- Use official platform reporting mechanisms and current terms.
- Rate-limit discovery and enforcement jobs.
- Do not bypass authentication, access controls, CAPTCHAs, paywalls, private groups, or platform security.
