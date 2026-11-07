# 0004: Per-field last-writer-wins with a hybrid logical clock

- Status: accepted (2026-11-07)

## Context
With file-based sync (ADR 0003), changes from several devices arrive late and in any order.
Per-row LWW would let a stale edit on one device (for example a note) overwrite a newer field on
another (for example a timer's `end_utc`), and a stopped timer would run again.

## Decision
Every write is a change that sets only the fields it changes, tagged with an **HLC**. Every field
keeps the value with the highest HLC. Deletes are a `deleted` tombstone field. After each merge,
deterministic resolve rules restore the "at most one open session / running entry" rules.

## Consequences
- Merging is idempotent and commutative: files can be applied in any order, any number of times.
  A property-based test checks this.
- Rows can be temporarily incomplete (an update arrives before its create), so all synced columns
  are nullable and incomplete rows are ignored.
- The HLC tolerates small clock differences between devices.
