# Fingerprinting and embedding architecture

## Why multiple fingerprint types

Pir separates matching signals:

- Audio: robust audio fingerprinting for authorized reference material.
- Video: temporal/perceptual fingerprints for authorized reference material.
- Image: perceptual image hashes/features.
- Text: exact/near-duplicate text signals.
- Semantic: vector embeddings for semantic retrieval and triage.

A semantic embedding is not a substitute for a media fingerprint. Matching should combine independent signals and pass uncertain results to review.

## Model registry

Every model is versioned in `fingerprint_models`. Do not silently replace a model version after fingerprints have been generated. Create a new model/version and run a migration/reprocessing job.

## Job lifecycle

```text
queued -> processing -> completed
                    \-> failed
                    \-> cancelled
```

Workers should make jobs idempotent, increment `attempts`, store structured errors, and use bounded retries.

## 3072-dimensional vectors

The current schema uses `vector(3072)` as the project baseline because the platform previously evaluated 3072-dimensional embedding candidates. Before the first production migration, lock the exact embedding model and dimension. If a different dimension is selected, change the column and HNSW index in a new migration.

## Matching pipeline

```text
Authorized reference
        |
        +--> media fingerprint
        +--> text features
        +--> semantic embedding
        |
        v
   candidate retrieval
        |
        v
  multi-signal scoring
        |
   +----+----+
   |         |
 high      uncertain
   |         |
   v         v
case       human review
```

This infrastructure does not authorize scraping or access to private content. Discovery connectors must use lawful/public/API-permitted sources and comply with platform terms, rate limits, privacy requirements, and applicable copyright law.
