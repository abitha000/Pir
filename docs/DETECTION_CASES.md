# Detection case management

A detection is a candidate infringement, not automatically a confirmed infringement.

## Lifecycle

`detected → triage → rights_review → evidence_review → notice_ready → submitted → platform_pending → removed/ rejected/ disputed → closed`

A case may also return to `triage` when a recheck produces new information.

## Scoring

Store confidence and match score separately:

- `confidence`: normalized confidence in the detection decision (0–100).
- `match_score`: raw/model-specific similarity score.
- `match_method`: fingerprint, semantic retrieval, metadata, human report, or a combination.

Never turn a model score directly into a legal conclusion. Thresholds should be calibrated against a labeled evaluation corpus and reviewed periodically.

## Human review

High-confidence detections can be prioritized for review, but enforcement should require verified rights and sufficient evidence. Ambiguous matches must remain reviewable without triggering an automatic legal notice.

## Evidence

Every enforcement-ready case should link to one or more evidence items. Evidence objects carry cryptographic hashes and custody events from the evidence module.

## Multi-tenant security

Cases are scoped to `organization_id` and protected by RLS. Cross-organization access must never depend on a frontend filter.
