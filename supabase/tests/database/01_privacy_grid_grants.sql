-- Privacy grid, part 1: table privileges (anon, authenticated) x tables x operations.
-- Expected values are the TARGET state (docs/sprint-1.md task 3). On the live baseline this file
-- fails for findings E and L (docs/security-audit.md). SELECT is covered by behavior in
-- 02_privacy_grid_rls.sql; MAINTAIN is not checked because Postgres 16 has no such privilege.
-- purchase_buyers is checked once the table exists (task 3); it must grant nothing to clients.
begin;
create extension if not exists pgtap with schema extensions;
select plan(61);

select ok(
  has_table_privilege(g.role, 'public.' || g.tbl, g.priv) is not distinct from g.expected,
  format('%s: %s should%s have %s on public.%s',
    g.finding, g.role, case when g.expected then '' else ' not' end, g.priv, g.tbl)
)
from (
  select r.role, t.tbl, p.priv,
    -- authenticated keeps INSERT and DELETE on wishlists and items; nothing else is granted at table
    -- level anywhere. UPDATE is granted per column only (checked below).
    (r.role = 'authenticated' and t.tbl in ('wishlists', 'items')
      and p.priv in ('INSERT', 'DELETE')) as expected,
    case when t.tbl = 'purchases' and p.priv = 'INSERT' then 'E' else 'L' end as finding
  from (values ('anon'), ('authenticated')) r(role)
  cross join (values ('wishlists'), ('items'), ('purchases')) t(tbl)
  cross join (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')) p(priv)
  order by r.role, t.tbl, p.priv
) g;

select ok(
  to_regclass('public.purchase_buyers') is null
  or not (
    has_table_privilege(r.role, 'public.purchase_buyers', 'SELECT')
    or has_table_privilege(r.role, 'public.purchase_buyers', 'INSERT')
    or has_table_privilege(r.role, 'public.purchase_buyers', 'UPDATE')
    or has_table_privilege(r.role, 'public.purchase_buyers', 'DELETE')
    or has_table_privilege(r.role, 'public.purchase_buyers', 'TRUNCATE')
  ),
  format('K: %s has no privilege on public.purchase_buyers (when it exists)', r.role)
)
from (values ('anon'), ('authenticated')) r(role);

-- UPDATE is column-limited: only the columns the app edits are writable by authenticated. id,
-- wishlist_id, owner_id, share_slug and the timestamps must not be, otherwise PATCHing an id leaks
-- purchase status through the foreign keys and wishlist_id can move an item (and lose its reservation).
select ok(
  has_column_privilege('authenticated', 'public.' || c.tbl, c.col, 'UPDATE') is not distinct from c.expected,
  format('L: authenticated should%s have UPDATE on public.%s.%s', case when c.expected then '' else ' not' end, c.tbl, c.col)
)
from (values
  ('items', 'title', true), ('items', 'merchant_url', true), ('items', 'price', true),
  ('items', 'image_url', true), ('items', 'note', true), ('items', 'position', true),
  ('items', 'id', false), ('items', 'wishlist_id', false),
  ('items', 'created_at', false), ('items', 'updated_at', false),
  ('wishlists', 'title', true), ('wishlists', 'description', true),
  ('wishlists', 'id', false), ('wishlists', 'owner_id', false), ('wishlists', 'share_slug', false),
  ('wishlists', 'created_at', false), ('wishlists', 'updated_at', false)
) c(tbl, col, expected);

-- No column-level privilege hides behind the table-level checks above.
select ok(
  not has_any_column_privilege('anon', 'public.' || t.tbl, 'INSERT, UPDATE, REFERENCES'),
  format('L: anon has no column-level write privilege on public.%s', t.tbl)
)
from (values ('wishlists'), ('items'), ('purchases')) t(tbl);

select ok(
  not has_any_column_privilege('authenticated', 'public.purchases', 'INSERT, UPDATE, REFERENCES'),
  'E: authenticated has no column-level write privilege on public.purchases'
);

select ok(
  to_regclass('public.purchase_buyers') is null
  or not has_any_column_privilege(r.role, 'public.purchase_buyers', 'SELECT, INSERT, UPDATE, REFERENCES'),
  format('K: %s has no column-level privilege on public.purchase_buyers (when it exists)', r.role)
)
from (values ('anon'), ('authenticated')) r(role);

select * from finish();
rollback;
