-- Privacy grid, part 3: catalog checks. On the live baseline this file fails for findings
-- I, M, N and O (docs/security-audit.md).
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

select ok(
  (select pg_get_expr(d.adbin, d.adrelid) !~* 'md5\(|\mrandom\('
   from pg_attrdef d
   join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
   where d.adrelid = 'public.wishlists'::regclass and a.attname = 'share_slug'),
  'I: wishlists.share_slug default does not come from md5(random())'
);

-- M: no command has more than one permissive policy (an ALL policy counts for every command)
select is(
  (select count(*)::int
   from (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE')) c(cmd)
   where (select count(*) from pg_policies p
          where p.schemaname = 'public' and p.tablename = t.tbl and p.permissive = 'PERMISSIVE'
            and p.cmd in (c.cmd, 'ALL')) > 1),
  0,
  format('M: public.%s has no overlapping permissive policies', t.tbl)
)
from (values ('wishlists'), ('items'), ('purchases')) t(tbl);

select is(
  (select count(*)::int from pg_constraint
   where contype = 'f' and connamespace = 'public'::regnamespace
     and confrelid = 'auth.users'::regclass and confdeltype in ('a', 'r')),
  0,
  'N: no foreign key from public to auth.users blocks user deletion (NO ACTION / RESTRICT)'
);

select is(
  (select count(*)::int from pg_proc p
   where p.pronamespace = 'public'::regnamespace
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
     and not coalesce(p.proconfig::text ilike '%search_path=%', false)),
  0,
  'O: every function in public has a pinned search_path'
);

select * from finish();
rollback;
