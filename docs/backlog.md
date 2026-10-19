# Backlog

Ordered by priority. Status: `todo` / `doing` / `done`. Every build session updates this file
(see CLAUDE.md, "Working rules"). Finding IDs refer to docs/security-audit.md.

## Sprint 1

| # | Item | Status | Reason |
|---|---|---|---|
| 1 | Live baseline migration + `docs/security-audit.md` + untrack `supabase/.temp/` | doing | Audit doc, baseline migration (`20260708110000_live_baseline.sql`), regenerated types and `supabase/.temp/` untrack are done on `feature/task-1-baseline`. Left: `supabase db reset` check in a real Supabase stack (only a plain Postgres 16 was available), then the production history repair (docs/baseline-history-repair.md), which waits for owner approval. |
| 2 | Test infrastructure + privacy grid (Vitest, CI, pgTAP) | doing | Done on `feature/task-2-test-infra`: Vitest, `test`/`typecheck` scripts, `tester.md`, `.github/workflows/ci.yml` (5 jobs), `supabase/config.toml`, pgTAP grid in `supabase/tests/database/`. Grid fails on the baseline for B, E, I, K, L, M, N, O (proved on a local Postgres 16 with pgTAP, not on the Supabase stack). Left: first real CI run (`supabase start`, `db reset`, `supabase test db`); the `database` job is red until task 3. |
| 3 | Privacy fix (`reserve_item`, `purchase_buyers`, `get_shared_wishlist`, policies, grants, slug, FK) | doing | Done on `feature/task-3-privacy-fix`: migration `20260709100000_privacy_fix.sql`, app changes on `/w/[slug]`, hand-edited types, grid extended (`04_privacy_grid_functions.sql`). Grid 138/138 on a local Postgres 16 with pgTAP (Supabase roles stubbed), plus a baseline -> data -> migrate run that keeps the buyer. Left: first green CI run (`supabase db reset`, `supabase test db`), Opus review of the migration SQL, manual check on a Vercel preview, owner dump of the 3 tables, then the production apply in a separate approved session. |
| 4 | SSRF-safe fetch + auth on `fetchLinkMetadata` + generic JSON-LD extractor | todo | The metadata action is an unauthenticated SSRF proxy (G). |
| 5 | Provider spike: SerpApi vs DataForSEO (terms first, US$50) | todo | Provider coverage, accuracy, cost and terms for Canada are unverified. |
| 6 | Price schema migration (`products`, `offers`, `price_history`, cache and rate-limit tables) | todo | Needed before any price feature; waits on the spike decision. |

## After Sprint 1

| # | Item | Status | Reason |
|---|---|---|---|
| 7 | Provider adapter + candidate picker | todo | Core of the add-product flow: search, auto-match on GTIN/model, user confirms otherwise. |
| 8 | Best-price display on creator and guest item rows | todo | The visible outcome of price comparison. |
| 9 | Refresh cron with spending cap (+ `last_activity_at` for active lists) | todo | Prices go stale; refresh must stay within budget and ignore purchase status. |
| 10 | Price history display | todo | In MVP scope; data is collected from task 6 on. |
| 11 | Rate limits: reserve action, product search per user, per-domain fetch | todo | Each search costs money; reserve and fetch can be abused. |
| 12 | CAD display fix (UI shows "€"; dates use `fr-FR`) | todo | Target market is Canada. |
| 13 | Auth hardening: leaked password protection, min password length 8, email confirmation, redirect URLs, custom SMTP | todo | Advisor flags leaked password protection off (P); the login form allows 6-character passwords (`app/login/page.tsx`); live Auth settings and the default SMTP limits are unverified. |
| 14 | Paid Supabase tier | todo | Free projects auto-pause (Q); required before real users. |
| 15 | Staging Supabase project + Vercel env vars (Preview vs Production scoped) | todo | Previews must not use production data or its service-role key. |
| 16 | Migration drift check in CI (`supabase db diff --linked` empty) | todo | Hand-made dashboard changes caused the current drift. |
| 17 | Realtime integration tests (creator receives nothing; guest of list A receives nothing from list B; no names in payloads) | todo | Live Realtime behavior is untested (R); deferred from task 2. |
| 18 | Playwright smoke test (create list, add item, guest reserves, creator sees nothing) | todo | End-to-end proof on a Vercel preview. |
| 19 | Supabase security advisor clean before launch | todo | Pre-launch gate; run by the project owner with dashboard or connector access. |
| 20 | GitHub secret scanning push protection | todo | Provider and service-role keys must never reach the repo. |
| 21 | Backups confirmed + basic error monitoring | todo | Pre-launch gate. |
| 22 | Privacy notice (PIPEDA and Quebec Law 25) | todo | The app stores names and emails of Canadian users. |
| 23 | README | todo | The README is one line; contributors need setup, env vars and test commands. |
| 24 | Playwright worker for merchants that need a real browser | todo | Deferred out of the MVP; revisit only if the spike shows a measured gap. |
| 25 | Add `supabase/config.toml` (`supabase init`) | done | Added in task 2 (Postgres 17). Original reason: The repo has none, so `supabase db reset` and `supabase start` cannot run; needed by task 2 (CI pgTAP job). Found in task 1. |
| 26 | `supabase` CLI not installed in the cloud session (`node_modules` absent) | todo | Still open: `npm ci` works by hand, and Supabase Docker images cannot be pulled from the cloud session (CloudFront 403), so `supabase start` is CI-only. Original: Run `npm ci` in the session setup so CLI commands (types, db reset, migration list) work. Found in task 1. |
| 27 | Add `typecheck` script to `package.json` and run lint/typecheck in CI | done | Added in task 2. Original reason: Lint and tsc were red on main unnoticed; covered by task 2 (CI), listed so it is not forgotten. Found in the lint/typecheck fix. |
| 28 | Task 3 constraint found by the grid: once `anon` loses SELECT on `wishlists`/`items`, the `purchases` SELECT policy subquery fails with permission denied. Keep a SELECT grant without policies, or use a SECURITY DEFINER helper | done | Solved in task 3 with the SECURITY DEFINER helper `is_wishlist_owner` (see docs/decisions.md). Found in task 2; the creator-exclusion tests (`CREATOR-EXCL`) guard it. |
| 29 | Task 3 must keep `supabase/tests/database/02_privacy_grid_rls.sql` green and extend it with function cases (`reserve_item`, `get_shared_wishlist`, PUBLIC EXECUTE) | done | Function cases are in `04_privacy_grid_functions.sql`. Sprint 1 task 3 definition of done. |
| 30 | Regenerate `lib/supabase/database.types.ts` with the CLI against the migrated schema | todo | Task 3 hand-edited the file (purchases, purchase_buyers, three functions) because `supabase gen types` needs Docker and the connector reads the live, unmigrated schema. Regenerate in CI or locally and diff. |
| 31 | `get_shared_wishlist` returns `jsonb`, so its payload is typed in `app/w/[slug]/shared-wishlist.ts` (zod), not in the generated types | todo | Consider a `returns table` variant if the payload grows. Found in task 3. |
| 32 | Rate limit and abuse control on `reserve_item` and `get_shared_wishlist` (anonymous callers, slug guessing) | todo | Both are callable by `anon`. Covered in spirit by item 11; found in task 3. |
| 33 | Composite FK `(item_id, wishlist_id)` -> `items (id, wishlist_id)` so `purchases.wishlist_id` cannot drift if an item is ever moved between lists | todo | No client path moves an item today. Found in task 3. |
| 34 | Guests can list every `(item_id, wishlist_id, created_at)` row of `purchases` (needed for Realtime); consider scoping it. Also verify on the Vercel preview that the creator receives no Realtime INSERT and a guest does | todo | No buyer identity is exposed. Reviewer WARN in task 3; covered by item 17 for the automated test. |

## Done

| Item | Status | Reason |
|---|---|---|
| Planning docs (`docs/price-comparison.md`, `docs/sprint-1.md`, `docs/backlog.md`, `docs/decisions.md`, `docs/security-audit.md`) | done | Architecture and sprint plan written down before any build work. |
| Fix `npm run lint` and `npx tsc --noEmit` on main | done | `react-hooks/set-state-in-effect` in `add-item-form.tsx` and unresolved `public/logo.png` import in `navbar.tsx`; both fixed on `feature/fix-lint-typecheck`, lint, tsc and build green. |
