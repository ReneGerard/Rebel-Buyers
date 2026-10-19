# Price comparison architecture

Status: decided at the architecture level on 2026-10-19. The choice of provider waits on the spike
(docs/sprint-1.md, task 5). Each decision is logged in docs/decisions.md.

## Goal

When a user adds a product (name, merchant URL or typed UPC/EAN/ISBN), the app finds offers from
several Canadian merchants, stores them, shows the best price, refreshes them over time and keeps
a price history.

## Decisions

1. **Discovery and refresh go through a third-party shopping-data provider** (Google Shopping data,
   Canada location). A single provider call per product returns every merchant at once. Candidates
   are SerpApi and DataForSEO; the spike picks one. Bright Data (looks enterprise-priced) and Apify
   actors (third-party maintained, uneven quality) are fallbacks only.
2. **Own extraction is narrow.** One generic JSON-LD/OpenGraph extractor, using plain fetch
   through the SSRF-safe client, runs on Vercel. It is used to:
   - identify a pasted merchant link (GTIN, brand, model number, name, price, currency);
   - cover merchants the provider misses, only if they serve structured data and their
     robots.txt/terms allow it.
   Large merchants (Amazon.ca, Best Buy, Walmart.ca, Costco) block plain fetches, so own
   extraction is not used to refresh them.
3. **Per-merchant adapters exist only where the generic extractor fails.** Each one sits behind
   the common interface, notes its robots.txt/terms check in the file, and ships with fixtures.
4. **No Playwright worker in the MVP.** It adds a server to operate, an exposed endpoint and
   database credentials outside Vercel, and sites that need a real browser usually forbid scraping.
   Revisit only if the spike shows a measured gap on merchants users actually add.
5. **"Best price" rule:** CAD only, new condition, ships to Canada, compared on price plus shipping
   (unknown shipping counts as 0 and is labelled), in stock or stock unknown. Prices are stored
   as integer cents.
6. **Products are a shared catalog.** One product row serves many items, so the cache works and
   refreshes are not duplicated. `items.product_id` is nullable: an unmatched item stays usable
   with its manual price.
7. **The catalog is publicly readable.** `products`, `offers` and `price_history` hold merchant data
   and no identities. RLS stays on, with a SELECT policy for everyone and no write policy. The
   only exposure is "someone wants product X".
8. **Only the server writes price data,** using the service-role key from a server-only module, after
   the auth and ownership checks. The cache and rate-limit tables have no policies at all.
9. **Cost control:**
   - every provider call goes through a query cache that also logs cost; the same query is never
     sent twice within the cache window;
   - per-user rate limit on searches;
   - a global daily spending cap that stops provider calls when reached.
10. **Refresh:** a daily Vercel Cron job protected by `CRON_SECRET`, limited to products on active
    lists. An active list is one viewed by its creator or a guest in the last 30 days
    (`wishlists.last_activity_at`, written at most once a day). Each product is refreshed at most
    every 3 days, within the spending cap.
11. **Privacy rule for price features:** nothing the creator sees may depend on purchase status.
    Purchased and unpurchased items are refreshed on the same schedule; counts, sort order and
    "last updated" times ignore purchases.
12. **Adding a product must not block the UI.** The user confirms a candidate, the item is saved
    immediately, and offers are fetched after the response (Next.js `after()`).

## Interfaces

```ts
// One implementation per provider (SerpApi or DataForSEO, after the spike).
interface OfferSource {
  search(query: ProductQuery): Promise<Candidate[]>;   // by GTIN, or by name (+ brand)
  getOffers(ref: ProviderProductRef): Promise<Offer[]>; // every merchant for one product
}

// Generic JSON-LD/OpenGraph extractor first; per-merchant overrides only where it fails.
interface MerchantExtractor {
  canHandle(url: URL): boolean;
  extract(html: string, url: URL): ExtractedProduct; // gtin, mpn, brand, name, price, currency
}
```

Every adapter fails gracefully: on error it returns no data, the item stays usable, and the price
is shown as missing. An adapter never throws through to the page.

## Matching rules

1. **Classify the input.**
   - 8, 12 or 13 digits with a valid check digit is a GTIN (UPC-A, EAN-13, ISBN-13, EAN-8).
   - A URL goes through the SSRF-safe fetch, then the extractor (`gtin*`, `mpn`, `brand`, `name`).
     If a GTIN is found, search by GTIN; otherwise search by brand + name.
   - Anything else is searched as a name.
2. **Automatic match only on an exact GTIN** (normalized to GTIN-14) **or an exact brand + model
   number.**
3. **Otherwise the user confirms.** The app shows the top 3–5 candidates (image, title, price), and
   the user picks one or chooses "none of these", in which case the item stays manual.
4. **Record how the match was made:** `match_method` is `gtin`, `mpn` or `user_confirmed`.
5. **Outlier guard:** an offer priced below 30% of the product's median offer is flagged and left out
   of the best price (it is usually a mismatched accessory).

## Provider spike (sprint task 5)

**Before spending anything:** read both providers' terms on storing, caching and displaying data to
end users, and on attribution. If a provider's terms forbid our use, it is dropped from the spike.

- **Budget:** up to US$50 in total.
- **The 20 products (ground truth collected by hand by the project owner, about 1 hour):**
  - 6 searched by UPC/ISBN (electronics, LEGO, a book)
  - 6 searched by name
  - 4 from pasted Canadian merchant links
  - 4 hard cases: clothing with size/colour, a niche item, a French product name, a bundle
- **Ground truth per product:** the correct product and the real lowest CAD price from 3–5 merchants,
  recorded on day 0.
- **Volume:** about 20 products × 3 input types × 2 providers (search + offers), plus one rerun:
  about 400–500 calls.

| Metric | Pass threshold |
|---|---|
| Correct product ranked first, UPC searches | ≥ 80% |
| Correct product in the top 5, name searches | ≥ 85% |
| Products with ≥ 3 Canadian merchants | ≥ 70% |
| Prices within 2% or $1 of the merchant page (5 offers per provider, checked by hand) | ≥ 90% |
| GTIN present in results; links go to the merchant, not a Google redirect | Measured |
| Search latency, p95 | ≤ 8 s |
| Projected cost for 500 active products refreshed every 3 days | ≤ US$30/month |
| Terms allow storing and displaying the data | Required |
| Price drift on the rerun after 48–72 h | Measured |

- **If neither provider passes:** ship own extraction plus manual price, and decide again.
  Multi-merchant comparison is not built on a provider that failed the spike.
- **Deliverables:**
  - a script in `scripts/spike/`, outside the app;
  - a results CSV and written analysis in `docs/spike/`;
  - raw responses saved as future adapter fixtures, with API keys removed;
  - the decision recorded in docs/decisions.md.
- **Secrets:** provider keys live only in the cloud environment settings (Network secrets), as
  `SERPAPI_API_KEY`, `DATAFORSEO_LOGIN` and `DATAFORSEO_PASSWORD`. The network policy must allow
  `serpapi.com` and `api.dataforseo.com`. Keys never go in the repo.

## Schema outline (sprint task 6, after the spike decision)

```sql
-- products: shared catalog
create table public.products (
  id uuid primary key default gen_random_uuid(),
  gtin text,                         -- normalized GTIN-14
  brand text,
  mpn text,
  title text not null,
  image_url text,
  provider text,
  provider_product_id text,
  match_method text check (match_method in ('gtin', 'mpn', 'user_confirmed')),
  last_refreshed_at timestamptz,
  refresh_status text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_product_id)
);
create unique index products_gtin_key on public.products (gtin) where gtin is not null;

alter table public.items add column product_id uuid references public.products on delete set null;
alter table public.wishlists add column last_activity_at timestamptz;

create table public.offers (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products on delete cascade,
  merchant_name text not null,
  merchant_domain text not null,
  url text not null,
  price_cents integer not null check (price_cents > 0),
  shipping_cents integer check (shipping_cents >= 0),
  currency char(3) not null check (currency = 'CAD'),
  condition text not null check (condition in ('new', 'used', 'refurbished')),
  in_stock boolean,
  source text not null check (source in ('provider', 'extraction')),
  source_ref text not null,          -- provider name or adapter id
  status text not null default 'active' check (status in ('active', 'stale', 'gone')),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  last_checked_at timestamptz not null default now(),
  unique (product_id, source, merchant_domain, condition)
);

-- written only when price, shipping or stock changes
create table public.price_history (
  id bigint generated always as identity primary key,
  offer_id uuid not null references public.offers on delete cascade,
  price_cents integer not null,
  shipping_cents integer,
  in_stock boolean,
  recorded_at timestamptz not null default now()
);
create index price_history_offer_recorded_idx on public.price_history (offer_id, recorded_at desc);

-- cache + cost log; server only
create table public.provider_queries (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  query_kind text not null,          -- 'gtin' | 'name' | 'offers'
  query_normalized text not null,
  locale text not null,              -- e.g. 'ca-en'
  requested_by uuid references auth.users on delete set null,
  response jsonb,
  cost_micros integer not null default 0,
  status text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (provider, query_kind, query_normalized, locale)  -- refresh = upsert on this key
);

-- per-domain rate limiting for own extraction; server only; rows older than 1 day are purged by the refresh cron
create table public.domain_fetch_log (
  id bigint generated always as identity primary key,
  domain text not null,
  fetched_at timestamptz not null default now()
);
create index domain_fetch_log_domain_idx on public.domain_fetch_log (domain, fetched_at desc);

-- best offer per product: min(price + shipping) over active, not-out-of-stock, non-outlier offers
create view public.product_best_offer with (security_invoker = true) as ...;  -- query written in task 6

-- RLS on every table
alter table public.products enable row level security;          -- SELECT to anon, authenticated using (true)
alter table public.offers enable row level security;            -- SELECT to anon, authenticated using (true)
alter table public.price_history enable row level security;     -- SELECT to anon, authenticated using (true)
alter table public.provider_queries enable row level security;  -- no policies
alter table public.domain_fetch_log enable row level security;  -- no policies
-- No INSERT/UPDATE/DELETE policies anywhere: writes come from the service role only.
-- Supabase default privileges grant ALL on new public tables to anon/authenticated (finding L), so:
revoke all on public.products, public.offers, public.price_history,
  public.provider_queries, public.domain_fetch_log from anon, authenticated;
grant select on public.products, public.offers, public.price_history to anon, authenticated;
revoke all on public.product_best_offer from anon, authenticated;
grant select on public.product_best_offer to anon, authenticated;
-- The task 6 grid checks these grants.
```

Files this will touch when it is built: the new migration, `lib/supabase/database.types.ts`, the
item server actions, the add-item form and both item rows (creator and guest).
