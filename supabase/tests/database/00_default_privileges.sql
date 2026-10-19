-- Privacy grid, part 0: the stack must give new objects the default privileges production has.
-- On Supabase, a table created in public by the migration role is readable and writable by anon
-- and authenticated unless the migration revokes it. The migration's REVOKE statements (for example
-- on purchase_buyers) are only tested for real when this default is present: on a stack without it,
-- a missing REVOKE would go unnoticed because nothing was granted in the first place.
-- This is a functional probe, not a catalog check: it creates a scratch table and function as the
-- migration role (the role running this test) and reads what anon and authenticated got. The
-- transaction is rolled back.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

create table public.__grid_default_probe (id int);
create function public.__grid_default_probe_fn() returns int language sql as 'select 1';

-- One test per privilege: has_table_privilege with a list is true when ANY of them is held.
select ok(
  has_table_privilege(r.role, 'public.__grid_default_probe', p.priv),
  format('DEFAULTS: %s gets %s on a new table in public, as in production. This stack does not match production default privileges, so every REVOKE in the migrations would be tested vacuously. The baseline migration 20260708110000_live_baseline.sql records them with ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA public; check that it ran as that role and that its statements are intact', r.role, p.priv, current_user)
)
from (values ('anon'), ('authenticated')) r(role)
cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) p(priv);

select ok(
  has_function_privilege(r.role, 'public.__grid_default_probe_fn()', 'EXECUTE'),
  format('DEFAULTS: %s gets EXECUTE on a new function in public, as in production (see the message above to align the stack)', r.role)
)
from (values ('anon'), ('authenticated')) r(role);

select ok(
  has_function_privilege('public', 'public.__grid_default_probe_fn()', 'EXECUTE'),
  'DEFAULTS: PUBLIC gets EXECUTE on a new function (Postgres default), as in production'
);

select * from finish();
rollback;
