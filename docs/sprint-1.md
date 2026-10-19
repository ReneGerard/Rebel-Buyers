# Sprint 1

Privacy first, then the price comparison groundwork. Findings referenced below (A–R) are in
docs/security-audit.md; the price architecture is in docs/price-comparison.md.

Models: **Opus** plans, audits and reviews SQL; **Sonnet** builds; **Haiku** subagents (`tester`,
`file-editor`) do the mechanical work. The `reviewer` subagent runs before every commit.

## Rules for every database change in this sprint

- The production data is test-only (2 users, 1 wishlist, 3 items, 1 purchase), so there is no backfill.
- A staging project is not a blocker for the privacy fix.
- Before anything is applied to production:
  1. the project owner dumps the 3 tables to a local file;
  2. the migration passes the privacy grid on a local Supabase in CI;
  3. the project owner explicitly approves applying it, in a separate session.
- Claude sessions use the Supabase connector read-only: list tables, list migrations, advisors and
  SELECT queries. No `apply_migration`, no DDL or DML through `execute_sql`, no branches.

## Tasks

### 1. Live baseline migration + security audit + untrack `supabase/.temp/`

Fixes A, H, J.

- Reconstruct the live schema from the catalog through read-only queries:
  - tables and columns
  - constraints, including FK delete rules
  - indexes
  - policies
  - grants
  - functions and triggers (including `set_updated_at`)
  - the `supabase_realtime` publication
- Write it as one baseline migration, so the repo can rebuild the live database. The live
  migration history currently lists the 4 repo files, so the history has to be repaired.
  Repairing it writes to production's migration table, which counts as a production change and
  follows the approval rule above.
- `docs/security-audit.md` is part of this task (written on 2026-10-19).

**Definition of done**
- `docs/security-audit.md` lists every finding with its status and evidence. *(done)*
- The baseline migration rebuilds, on a local Supabase (`supabase db reset`), a schema whose catalog
  query output matches the live one. Anything that could not be captured is listed in the
  migration header.
- The steps to repair the production migration history are written down and wait for approval.
- `lib/supabase/database.types.ts` is regenerated from the schema.
- `supabase/.temp/` is untracked (`git rm --cached`), and the ignore rule stays.

**Model:** Opus for the audit and the catalog queries; Sonnet writes the baseline; Haiku untracks
`supabase/.temp/`.

### 2. Test infrastructure + privacy grid

- Vitest; `test` and `typecheck` scripts in `package.json`.
- `.claude/agents/tester.md` also runs `npm test`.
- GitHub Actions CI with five steps: lint, typecheck, test, build, and a pgTAP job (`supabase start`,
  `supabase db reset`, `supabase test db`).
- pgTAP privacy grid: roles (anon, creator, other signed-in user, signed-in guest) × tables
  (`wishlists`, `items`, `purchases`, and `purchase_buyers` once it exists) × operations
  (select, insert, update, delete, truncate). It also covers:
  - the creator-exclusion subquery once broad guest policies are gone;
  - the INSERT error oracle (E);
  - spoofing `purchased_by_user_id`;
  - listing every wishlist (B);
  - reading buyer names (K);
  - TRUNCATE grants (L).
- Realtime integration tests are not in this task (they are in the backlog).

**Definition of done**
- `npm test` and `npm run typecheck` run locally and in CI.
- CI runs all five steps on every push and pull request.
- The grid runs in CI against the task 1 baseline and **fails** on every confirmed finding
  (B, E, I, K, L, M, N, O). Each failure is named after its finding ID.
- `tester` reports unit-test results.

**Model:** Opus designs the grid; Sonnet implements; Haiku edits the scripts and `tester.md`.

### 3. Privacy fix

Fixes B, C (remaining part), D, E, I, K, L, M, N, O.

New migration:
- `purchases` keeps only `item_id` (unique), `wishlist_id` (copied from the item, for the Realtime
  filter) and `created_at`.
- `purchase_buyers` (`purchase_id`, `buyer_name`, `buyer_user_id`): RLS on, zero policies, no grants
  to `anon` or `authenticated`.
- `reserve_item(item_id, buyer_name)` is a `SECURITY DEFINER` function with a pinned `search_path`. It:
  - refuses the creator **before** reading purchase status, with one generic error;
  - inserts both rows in one transaction;
  - sets `buyer_user_id` from `auth.uid()` only.

  Direct INSERT on `purchases` is removed.
- Both functions: `REVOKE EXECUTE ... FROM PUBLIC`, then `GRANT EXECUTE` to `anon` and `authenticated`
  only (Postgres grants EXECUTE to PUBLIC by default). `gen_random_bytes` comes from pgcrypto in the
  `extensions` schema on Supabase, so call it schema-qualified because `search_path` is pinned.
- `get_shared_wishlist(slug)` is a `SECURITY DEFINER` function that returns the list, its items and a
  taken flag. The flag is `null` for the creator.
- Creator-excluding SELECT policy on `purchases`.
- Drop the broad and duplicate guest policies on `wishlists` and `items`.
- Revoke excess grants (TRUNCATE and anything not needed) from `anon` and `authenticated`.
- Set `search_path` on `set_updated_at`.
- `share_slug` default generated from `gen_random_bytes`; existing slugs regenerated (test data only).
- Change the `purchased_by_user_id` (now `buyer_user_id`) FK to `ON DELETE SET NULL`.

App changes:
- `app/w/[slug]` reads through `get_shared_wishlist`.
- The reserve action calls `reserve_item` and validates with zod: item id as a UUID, buyer name trimmed,
  1–100 characters.
- The Realtime subscription is filtered on `wishlist_id=eq.<id>`.
- Types are regenerated.

**Definition of done**
- The task 2 grid is fully green in CI, and extended with function cases for each role:
  - the creator calls `reserve_item` and gets the same generic error whether the item is taken or not;
  - the creator calls `get_shared_wishlist` and gets `null` taken flags;
  - `PUBLIC` has no EXECUTE on either function.
- The `reviewer` reports no BLOCK.
- Opus has reviewed the SQL.
- The manual check on a Vercel preview passes: the creator's account sees no status, and a guest
  sees the live update.
- Production apply follows the approval rule above.

**Model:** Sonnet builds; Opus reviews the migration SQL before merge.

### 4. SSRF-safe fetch

Fixes G.

- `lib/net/safe-fetch.ts`:
  - http/https only, ports 80 and 443;
  - every resolved IP checked against private, loopback, link-local, carrier-grade NAT, IPv6
    unique-local and IPv4-mapped ranges;
  - connects to the IP it checked (no second DNS lookup);
  - follows redirects by hand, max 3, each one re-checked;
  - total timeout that includes the body read;
  - 1 MB size cap;
  - content-type check.
- `fetchLinkMetadata` requires a signed-in user, validates the URL with zod, and uses the safe fetch.
- The generic JSON-LD/OpenGraph extractor reads GTIN, model number, brand, price and currency.

**Definition of done**
- Unit tests pass for blocked targets: `127.0.0.1`, `169.254.169.254`, `[::1]`, `10.0.0.0/8`,
  a redirect to a private IP, a hostname that resolves to a private IP, a slow body, an oversize body.
- Fixture tests pass for the extractor (saved HTML pages), with no network access during tests.
- A call without a session is refused.
- Any fetch or parse failure returns no metadata and the item form stays usable.
- Known gap: `fetchLinkMetadata` has no per-user or per-domain rate limit until backlog item 11.
- `tester` is green.

**Model:** Sonnet.

### 5. Provider spike: SerpApi vs DataForSEO

Details are in docs/price-comparison.md ("Provider spike").

- **Step 1, before spending anything:** check both providers' terms on storing, caching and
  displaying data, and on attribution. A provider whose terms forbid our use is dropped.
- **Step 2:** run the 20 products within US$50.

The project owner creates the accounts and keys (in the cloud environment's Network secrets) and
collects the ground truth by hand (about 1 hour).

**Definition of done**
- Terms check written up for both providers.
- Every metric measured with a pass/fail against its threshold.
- Results CSV and analysis in `docs/spike/`.
- Raw responses saved as fixtures, keys removed.
- Spend reported.
- The decision (provider chosen, or fall back to own extraction) recorded in docs/decisions.md.

**Model:** Opus for the terms review and the analysis; Sonnet builds the spike script.

### 6. Price schema migration (only after the task 5 decision)

**Definition of done**
- Migration from the outline in docs/price-comparison.md, with RLS on every table and no excess grants.
- Privacy grid extended to the new tables (catalog readable, no client writes, server-only tables
  closed).
- Types regenerated.
- CI green; production apply follows the approval rule above.
- No UI in this task.

**Model:** Sonnet builds; Opus reviews the SQL.
