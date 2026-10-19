# Rebel Buyers — Claude Code Project Instructions

## Vision
Neutral multi-merchant gift wishlist web app. Buyers coordinate gift purchases without 
revealing to the list creator which item was bought or by whom. When a product is added, 
the app finds offers across several merchants and surfaces the best price (Google 
Shopping style).
Current phase: MVP / proof of concept.

## MVP scope — DO NOT exceed without explicit validation
In scope:
- Auth (email/password via Supabase Auth)
- Wishlist CRUD (title, description)
- Item CRUD (title, merchant link, optional price, image URL, note)
- Public share link (read-only for non-authenticated guests)
- Mark an item "purchased" (visible to other guests, NOT to the list creator)
- Realtime sync via Supabase Realtime
- Price comparison: when a user adds a product (name, merchant URL, or typed UPC), the 
  app retrieves offers from several merchants, stores them, shows the best price, 
  refreshes them over time and keeps a price history. Architecture is defined in 
  docs/price-comparison.md once decided; until it exists, ask before building.

Out of scope (Phase 2+, do not build without an explicit request):
- Camera / barcode scanning
- Merchant ads, affiliate monetization
- Native mobile app (React Native) — PWA only for now

## Stack
- Next.js 16 (App Router), React 19, TypeScript strict
- Tailwind CSS 4
- Supabase: Postgres + Auth + Realtime + Storage
- zod for validation
- Deployment: Vercel (preview deploy on every PR)
- No external state management (Zustand/Redux) unless justified

## Code conventions
- All code, variable names, comments: in English
- Conversation with the user: French is fine
- Functional components + hooks only
- Server Components by default; Client Components ("use client") only when interactivity requires it
- Validate inputs server-side AND client-side (zod)
- No `any` in TypeScript: type explicitly or use `unknown`
- Errors are always handled explicitly, never silent

## Database conventions
- Tables in snake_case, RLS enabled on ALL tables from day one
- Supabase migrations versioned in supabase/migrations/
- Never rely on critical business logic only on the client: duplicate validation in RLS policies
- Every new table or function needs, in the same migration: RLS enabled, an explicit `REVOKE` of the default privileges (from `anon` and `authenticated`, and from `PUBLIC` for functions) and explicit `GRANT`s of only what is needed, because production opens new objects to `anon` and `authenticated` by default, and a pgTAP assertion for it in supabase/tests/database/.

## Git workflow
- Branches: feature/short-name, fix/short-name
- Clear commit messages, French or English
- Never commit .env.local or API keys

## Price comparison rules
- Headless-browser scraping (Playwright) never runs inside Vercel serverless functions. 
  Static HTML / JSON-LD / OpenGraph extraction and third-party data-provider API calls may.
- Every fetch of a user-supplied URL must be SSRF-safe: http/https only, resolve the host 
  and block private, loopback and link-local ranges, enforce timeouts and size limits.
- Provider API calls are cached; never call a provider twice for the same query within 
  the cache window. Only refresh products that belong to active lists.
- One generic JSON-LD/OpenGraph extractor is the default adapter; per-merchant adapters are added 
  only where it fails, all behind a common interface. A failing adapter degrades gracefully 
  (item stays usable, price missing), never breaks the page.
- Per-domain rate limiting. Check robots.txt/ToS before adding a merchant adapter and note 
  the result in the adapter file.
- Product matching uses GTIN/UPC or model number first; otherwise the user confirms a candidate.
- Offer and price data live in Supabase with RLS like everything else.
- Every adapter ships with saved HTML/JSON fixtures so it can be tested offline.

## Agent orchestration
- Use the `tester` subagent to run lint, typecheck and build after any code change.
- Use the `file-editor` subagent for mechanical edits (renames, find/replace, moving files) 
  that need no architectural decision.
- Use the `reviewer` subagent before every commit. Never commit without a BLOCK/WARN/OK 
  report. Fix every BLOCK first.

## Working rules
- Run independent tool calls in parallel.
- Keep solutions minimal: no features, refactors, abstractions or defensive code beyond what the task needs.
- Be direct and specific. State real uncertainty once, plainly. No praise, no padding.
- On auth, RLS policies, or anything touching user data: surface the decision before implementing.
- On schema changes: list all affected files (migrations, database.types.ts, server actions, 
  components) before touching any of them.
- Every build session ends by updating docs/backlog.md (status of the tasks touched, new items discovered) and docs/decisions.md (any decision made), in the same PR as the code.

## When unsure about scope
If a request seems to widen the MVP (e.g. "add barcode scanning"), say so before coding: 
"This is outside the defined MVP scope. Build it anyway, or put it in the Phase 2 backlog?"
