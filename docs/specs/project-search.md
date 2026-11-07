# Spec: project search

Status: **normative**. Implemented in `packages/core/lib/src/search/project_search.dart`. Tests cite
`project-search.md §N`.

The project picker has one search field. It matches **name, project number, order number and
client** at once (concept §5, item 3).

## §1 Folding (applied to the query and the fields alike)

1. Lower case.
2. `ä→a`, `ö→o`, `ü→u`, `ß→ss`, and common accents (`é→e`, `ç→c`, …).
3. The digraphs `ae`, `oe`, `ue` become `a`, `o`, `u`. With steps 2 and 3, `Müller`, `Mueller` and
   `Muller` all become `muller`.
4. **Text fields** (name, client): every run of other characters (spaces, punctuation) becomes one
   space, which marks word starts.
5. **Number fields** (project number, order number): all non-letter, non-digit characters are
   **removed**, so `P-2026/014` becomes `p2026014`.

## §2 Tokens

The query is split at whitespace. **Every token must match at least one field.** An empty query
matches every project.

## §3 Match tiers for one token (lower is better)

| Tier | Number field | Text field |
|---|---|---|
| 0 | exact: the folded token equals the folded number, or the number minus its leading letters (`2026014` ↔ `P-2026/014`) | – |
| 1 | prefix: the number, or the number minus its leading letters, starts with the token | the token starts a word |
| 2 | the number contains the token | the field contains the token |
| 3 | fuzzy: the token's letters appear in order (tokens of ≥ 3 characters only) | same |

A token's tier is its best tier over all fields. A project's tier is the **worst** tier of its
tokens, so the weakest part of the query decides.

## §4 Order

1. Project tier, ascending.
2. Use count, descending (for example project entries in the last 90 days, passed in by the caller).
3. Last use, most recent first.
4. Name, alphabetically.

For an empty query, favorites come first, then order steps 2–4.

## §5 Filter and highlights

- Archived projects are excluded unless the caller asks for them.
- Each result carries the **ranges in the original strings** that matched, so the UI can highlight them.
