# Rights & asset management

This module is the legal foundation for enforcement. A detection must not become an enforcement action unless the organization has a verified right/authorization record for the relevant asset.

## Asset
A `copyright_assets` row represents the work being protected: film, series, episode, music, image, book, software or another protected work.

## Rights record
A `rights_records` row records:
- who holds the relevant right
- what right is controlled
- territory
- start/end dates
- verification status
- authorization reference
- supporting evidence location

The application should require legal/authorized review before changing a rights record to `verified`.

## Reference artifact
`asset_references` stores metadata about a reference file used by fingerprinting/detection. The actual bytes should live in private Supabase Storage buckets; Postgres stores the storage key and SHA-256 integrity hash.

## Enforcement gate
A future enforcement service should require:
1. Asset exists.
2. At least one applicable rights record is `verified`.
3. The rights record covers the target territory/time period.
4. The acting organization is authorized.
5. Evidence for the suspected infringement exists.
6. A human/legal approval is present when required.

Do not infer ownership merely from the title, filename, upload, or a user's statement.
