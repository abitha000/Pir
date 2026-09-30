# Database

This directory contains Supabase migrations. Apply them through the Supabase CLI or dashboard migration workflow.

The first migration establishes organizations, memberships, assets, reference fingerprints/embeddings, cases, evidence, enforcement actions, audit logs, indexes, enums, and baseline RLS.

Production note: review the embedding dimension against the exact embedding model selected before running the migration. If the model changes dimensions, create a new vector column/version rather than silently changing an existing production index.
