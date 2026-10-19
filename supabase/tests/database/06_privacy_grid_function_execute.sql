-- Privacy grid, part 6: who can EXECUTE every function in public, positive and negative.
-- The expected list below is the whole truth: a function missing from it fails the last test, so a
-- new function cannot be exposed to anon, authenticated or PUBLIC silently. Production opens new
-- functions to anon and authenticated by default (docs/decisions.md), so every migration that adds
-- one must revoke that default and grant explicitly, then add the function here.
-- postgres (owner), service_role and supabase_admin are trusted and not checked.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

create temp table expected_execute (fn text, anon boolean, authenticated boolean, public_ boolean) on commit drop;
insert into expected_execute values
  ('reserve_item', true, true, false),
  ('get_shared_wishlist', true, true, false),
  -- runs inside the purchases policy, which is evaluated with the querying role's privileges
  ('is_wishlist_owner', true, true, false),
  -- trigger function: nobody needs EXECUTE, Postgres checks it only when the trigger is created
  ('set_updated_at', false, false, false);

select is(
  has_function_privilege(r.role, p.oid, 'EXECUTE'), r.expected,
  format('E: %s %s EXECUTE on public.%s', r.role, case when r.expected then 'holds' else 'does not hold' end, p.proname)
)
from pg_proc p
join expected_execute e on e.fn = p.proname
cross join lateral (values ('anon', e.anon), ('authenticated', e.authenticated)) r(role, expected)
where p.pronamespace = 'public'::regnamespace
order by p.proname, r.role;

select is(
  exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a where a.grantee = 0 and a.privilege_type = 'EXECUTE'),
  e.public_,
  format('E: PUBLIC %s EXECUTE on public.%s', case when e.public_ then 'holds' else 'does not hold' end, p.proname)
)
from pg_proc p
join expected_execute e on e.fn = p.proname
where p.pronamespace = 'public'::regnamespace
order by p.proname;

select is(
  (select array_agg(a.grantee::regrole::text order by a.grantee::regrole::text)
   from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where a.privilege_type = 'EXECUTE' and a.grantee <> 0
     and a.grantee::regrole::text not in ('anon', 'authenticated', 'postgres', 'service_role', 'supabase_admin')),
  null::text[],
  format('E: no unexpected role holds EXECUTE on public.%s', p.proname)
)
from pg_proc p
join expected_execute e on e.fn = p.proname
where p.pronamespace = 'public'::regnamespace
order by p.proname;

select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
     and p.proname not in (select fn from expected_execute)),
  null::text[],
  'E: every function in public is listed in this test (a new function must be added with its expected EXECUTE grants)');

select * from finish();
rollback;
