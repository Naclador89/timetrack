# 0007: Synced rows stored generically (JSON fields) in SQLite

- Status: accepted (2026-11-07)

## Context
Local storage uses drift/SQLite (ADR 0001). Synced data can be partial (an update can arrive before
its create) and newer app versions may add fields or tables that older versions don't know yet
(sync-format.md §6, §9). Typed columns per table would need migrations for every new field and
would drop unknown fields.

## Decision
All synced rows live in **one table** `synced_rows(tbl, row_id, fields JSON, field_clock JSON)`.
Local sync state has its own small tables (`outbox`, `pending_batches`, `seen_files`,
`folder_etags`, `local_values`). The field names per table are specified in
`docs/specs/data-model.md`. `core/lib/src/data/mapping.dart` turns complete rows into model classes.

## Consequences
- Unknown fields and tables are kept, so no replay or schema migration is needed when the data
  model grows.
- Queries filter in Dart after loading by table. That's fine for personal data volumes (a few
  thousand rows a year). If needed, SQLite JSON functions (`json_extract`) can back indexes later.
- Typing errors (wrong value types from a buggy client) are handled at mapping time: such rows are
  skipped like incomplete ones.
