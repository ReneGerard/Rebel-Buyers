# Backlog

Ordered by priority. Status: `todo` / `doing` / `done`. Every build session updates this file
(see CLAUDE.md, "Working rules"). Finding IDs refer to docs/security-audit.md.

## Sprint 1

| # | Item | Status | Reason |
|---|---|---|---|
| 1 | Live baseline migration + `docs/security-audit.md` + untrack `supabase/.temp/` | doing | The migrations cannot rebuild the live DB and `purchases` is in no migration (A, H, J); audit doc done, baseline and untrack remain. |
| 2 | Test infrastructure + privacy grid (Vitest, CI, pgTAP) | todo | No tests exist; the grid must fail on the confirmed leaks before they are fixed. |
| 3 | Privacy fix (`reserve_item`, `purchase_buyers`, `get_shared_wishlist`, policies, grants, slug, FK) | todo | Any anonymous visitor can read buyer names and enumerate every list today (B, K). |
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

## Done

| Item | Status | Reason |
|---|---|---|
| Planning docs (`docs/price-comparison.md`, `docs/sprint-1.md`, `docs/backlog.md`, `docs/decisions.md`, `docs/security-audit.md`) | done | Architecture and sprint plan written down before any build work. |
