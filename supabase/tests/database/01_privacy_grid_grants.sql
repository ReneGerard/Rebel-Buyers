-- Privacy grid, part 1: table privileges (anon, authenticated) x tables x operations.
-- Expected values are the TARGET state (docs/sprint-1.md task 3). On the live baseline this file
-- fails for findings E and L (docs/security-audit.md). SELECT is covered by behavior in
-- 02_privacy_grid_rls.sql; MAINTAIN is not checked because Postgres 16 has no such privilege.
-- purchase_buyers is checked once the table exists (task 3); it must grant nothing to clients.
begin;
create extension if not exists pgtap with schema extensions;
select plan(38);

select ok(
  has_table_privilege(g.role, 'public.' || g.tbl, g.priv) is not distinct from g.expected,
  format('%s: %s should%s have %s on public.%s',
    g.finding, g.role, case when g.expected then '' else ' not' end, g.priv, g.tbl)
)
from (
  select r.role, t.tbl, p.priv,
    -- authenticated keeps plain CRUD on wishlists and items; nothing else is granted anywhere
    (r.role = 'authenticated' and t.tbl in ('wishlists', 'items')
      and p.priv in ('INSERT', 'UPDATE', 'DELETE')) as expected,
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

select * from finish();
rollback;
