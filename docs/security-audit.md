# Security audit: purchase privacy and database exposure

- Date: 2026-10-19
- Project: Supabase production, ref `ookqbhipqnocwfkbaneo` ("Rebel-Buyers")
- Scope: can a list creator see who purchased what; what the anon/authenticated roles can read and write.
- Method: live audit run by the project owner (recorded verbatim below), then two items re-verified
  in a Claude session with read-only SQL through the Supabase connector (no DDL, no DML).

## Guarantee we are aiming for

- The creator's signed-in account can never read purchase data: not through tables, RPC,
  Realtime or server actions.
- No client role can ever read the buyer's identity (name or user id).
- Accepted limit: the share link is public, so a creator who opens it signed out (private window)
  sees which items are taken, like any guest.

## Live audit by the project owner (verbatim)

> - Data: 2 users, 1 wishlist, 3 items, 1 purchase (test data only).
> - CONFIRMED:
>   A. purchases is in no migration (live history = the 4 repo files).
>   B. wishlists and items have a SELECT policy `using (true)` for role public: anyone can
>      enumerate every list and share_slug.
>   D. supabase_realtime publication includes public.purchases.
>   E. purchases INSERT policy is `with_check (true)` for public: the creator can insert on
>      their own items, the unique(item_id) error reveals purchase status, and
>      purchased_by_user_id can be spoofed.
>   H. the migrations cannot rebuild the live database.
>   I. share_slug = substr(md5(random()), 1, 10), and lists are enumerable anyway.
> - NEW: the purchases SELECT policy "Non-owners can view purchase status" lets any anonymous
>   visitor read purchased_by_name and purchased_by_user_id for every list.
> - PARTLY REFUTED C: the creator IS blocked from SELECT on purchases at DB level (policy),
>   not only in the UI. Remaining leaks: the INSERT error, and signed-out browsing (accepted).
> - REFUTED F: purchases.item_id FK is ON DELETE CASCADE.
> - OTHER: anon and authenticated hold ALL table privileges including TRUNCATE; overlapping
>   duplicate policies on wishlists and items (6 each); purchased_by_user_id FK is NO ACTION
>   (blocks account deletion, a Law 25 erasure problem); advisors: set_updated_at has a
>   mutable search_path, leaked password protection is disabled.
> - NOT TESTED: G (SSRF, code review only), J, live Realtime behavior.
> - The free-tier project was auto-paused for inactivity and I restored it manually. A paid
>   tier is required before real users.

## Re-verification in this session (read-only SQL)

### purchases policies

```sql
select policyname, cmd, roles::text, permissive, qual, with_check
from pg_policies where schemaname = 'public' and tablename = 'purchases';
```

| Policy | Command | Roles | USING | WITH CHECK |
|---|---|---|---|---|
| Anyone can mark an item as purchased | INSERT | public | — | `true` |
| Non-owners can view purchase status | SELECT | public | `auth.uid() IS DISTINCT FROM (SELECT w.owner_id FROM items i JOIN wishlists w ON w.id = i.wishlist_id WHERE i.id = purchases.item_id) OR auth.uid() IS NULL` | — |

Result: matches the owner's audit (E, the new finding K, and C partly refuted). No UPDATE or DELETE
policy exists, so with RLS on, clients cannot update or delete rows. Their table grants still
include TRUNCATE, which RLS does not cover (see L).

Note for the fix: the creator exclusion works through a subquery on `items` and `wishlists`, and that
subquery runs under *their* RLS. Today it resolves because both tables are readable by everyone
(B). Once task 3 drops those broad policies, the subquery returns NULL for anyone but the creator.
`IS DISTINCT FROM NULL` stays true, so guests keep access and the creator stays excluded. The privacy
grid must cover this case explicitly so a later policy change cannot break it silently.

### Foreign key delete rules

```sql
select conrelid::regclass, conname, confrelid::regclass, confdeltype, pg_get_constraintdef(oid)
from pg_constraint where contype = 'f' and connamespace = 'public'::regnamespace;
```

| Table | Constraint | References | ON DELETE |
|---|---|---|---|
| items | items_wishlist_id_fkey | wishlists | CASCADE |
| purchases | purchases_item_id_fkey | items | CASCADE |
| purchases | purchases_purchased_by_user_id_fkey | auth.users | NO ACTION |
| wishlists | wishlists_owner_id_fkey | auth.users | CASCADE |

Result: matches the owner's audit (F refuted, N confirmed).

## Findings

Status values: confirmed, refuted, partly refuted, not tested. Severity: P0 = leaks purchase data
or identities now, P1 = abuse or integrity risk, P2 = hardening.

| ID | Finding | Status | Severity | Evidence |
|---|---|---|---|---|
| A | `purchases` table, RLS and policies are in no migration. | Confirmed | P1 | Owner audit: live migration history = the 4 repo files; migration `20260623100000` says purchases was applied by hand. |
| B | `wishlists` and `items` have a SELECT policy `using (true)` for role `public`: anyone with the public anon key can list every wishlist, its `share_slug` and every item. | Confirmed | P0 | Owner audit (live `pg_policies`). |
| C | The creator check is UI-only. | Partly refuted | P0 (remaining part) | The SELECT policy blocks the creator's account at DB level (re-verified above). Remaining leaks: the INSERT error oracle (E) and signed-out browsing (accepted limit). |
| D | `public.purchases` is in the `supabase_realtime` publication; the client subscribes to all purchase inserts with no filter (`app/w/[slug]/item-list.tsx`). | Confirmed (publication); live behavior not tested | P0 | Owner audit. Postgres changes delivers full rows to any subscriber that passes the SELECT policy, so with K every anonymous subscriber would receive buyer names for every list. Not observed live. |
| E | `purchases` INSERT policy is `with_check (true)` for `public`: the creator can insert on their own items; the `unique(item_id)` violation ("already marked") tells them an item is taken; `purchased_by_user_id` can be set to any user. | Confirmed | P0 | Owner audit; re-verified above. The `markAsPurchased` server action adds no creator check and no UUID validation. |
| F | Deleting a purchased item might fail and reveal its status. | Refuted | — | `purchases_item_id_fkey` is ON DELETE CASCADE (re-verified above). |
| G | `fetchLinkMetadata` (`app/dashboard/wishlist/[id]/actions.ts`) has no auth check, no block on private/loopback/link-local ranges, follows redirects, and its 5 s timeout does not cover the body read. | Not tested (code review only) | P0 | Code review. It is a public server-action endpoint, so anyone can use it as an SSRF proxy. |
| H | The migrations cannot rebuild the live database. | Confirmed | P1 | Owner audit. Migration 3 alters a table no migration creates; migration 4 renames `url`/`notes`, which migration 1 never creates. |
| I | `share_slug` = `substr(md5(random()), 1, 10)`: 40 bits from a non-cryptographic generator. | Confirmed | P2 (P0 while B stands) | Owner audit. Moot while lists are enumerable (B). |
| J | `supabase/.temp/` (project ref, pooler URL, no password) is tracked in git despite `.gitignore`. | Not tested in the live audit; confirmed in the repo | P2 | `git ls-files supabase/.temp` lists 9 files. |
| K | The purchases SELECT policy "Non-owners can view purchase status" lets any anonymous visitor read `purchased_by_name` and `purchased_by_user_id` for every list. | Confirmed | P0 | Owner audit; policy text re-verified above (all columns, `auth.uid() IS NULL` branch). |
| L | `anon` and `authenticated` hold ALL table privileges, including TRUNCATE (not covered by RLS). | Confirmed | P0 | Owner audit. |
| M | Overlapping duplicate policies on `wishlists` and `items` (6 each). | Confirmed | P2 | Owner audit. Permissive policies combine with OR, so the broadest one wins; it also makes the audit harder. |
| N | `purchased_by_user_id` FK is NO ACTION: deleting a user who reserved something fails. | Confirmed | P1 | Owner audit; re-verified above. Blocks account erasure (PIPEDA / Quebec Law 25). |
| O | Function `set_updated_at` has a mutable `search_path`. | Confirmed | P2 | Supabase security advisor (owner audit). |
| P | Leaked password protection is disabled in Supabase Auth. | Confirmed | P1 | Supabase security advisor (owner audit). |
| Q | The free-tier project was auto-paused for inactivity. | Confirmed | P1 (operations) | Owner restored it by hand. A paid tier is required before real users. |
| R | Live Realtime delivery (what a creator or a guest of another list actually receives). | Not tested | — | Moved to the backlog (Realtime integration tests). |

## Fix mapping

| Finding | Fixed by (docs/sprint-1.md) |
|---|---|
| A, H, J | Task 1: live baseline migration, untrack `supabase/.temp/` |
| B, C, D, E, I, K, L, M, N, O | Task 3: privacy fix migration, guarded by the task 2 grid |
| G | Task 4: SSRF-safe fetch |
| P, Q | Backlog: auth hardening, paid Supabase tier |
| R | Backlog: Realtime integration tests |

## Not captured

- Live Realtime behavior (R) and the SSRF path (G) were not exercised.
- Auth settings other than leaked password protection (password length, email confirmation,
  redirect URLs, SMTP) were not reviewed.
- Storage buckets and policies were not reviewed (the app does not use Storage today).
