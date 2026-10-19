-- Privacy grid, part 2: behavior per role. Roles: anon, creator (owner of the list), another
-- signed-in user (owns a different list), signed-in guest (owns nothing). Tables: wishlists, items,
-- purchases. Operations: select, insert, update, delete, truncate. It also guards:
--   * the creator-exclusion on purchases, which must keep working once the broad guest policies
--     on wishlists and items are dropped (docs/security-audit.md, "Note for the fix");
--   * the INSERT error oracle (E), spoofing purchased_by_user_id (E), listing every wishlist (B),
--     reading buyer names (K) and TRUNCATE grants (L).
-- Test descriptions start with the finding ID. On the live baseline this file fails for B, E, K, L.
-- grid.outcome() runs a statement as the current role and rolls it back, so tests do not interfere.
begin;
create extension if not exists pgtap with schema extensions;

create schema grid;
grant usage on schema grid to anon, authenticated;
create function grid.outcome(q text) returns text language plpgsql as $f$
declare n bigint;
begin
  begin
    execute q;
    get diagnostics n = row_count;
    raise exception using errcode = 'GR001', message = 'rows:' || n;
  exception
    when sqlstate 'GR001' then return sqlerrm;
    when others then return 'error:' || sqlstate;
  end;
end $f$;

-- grid.rows() counts the rows the current role can read; a permission error counts as 0 rows
create function grid.rows(q text) returns int language plpgsql as $f$
declare n int;
begin
  execute 'select count(*)::int from (' || q || ') s' into n;
  return n;
exception when insufficient_privilege then return 0;
end $f$;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'creator@example.test'), ('22222222-2222-2222-2222-222222222222', 'other@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'guest@example.test'), ('44444444-4444-4444-4444-444444444444', 'buyer@example.test');
insert into public.wishlists (id, owner_id, title, share_slug) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', '11111111-1111-1111-1111-111111111111', 'Creator list', 'grid-slug-1'),
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', '22222222-2222-2222-2222-222222222222', 'Other list', 'grid-slug-2');
insert into public.items (id, wishlist_id, title) values
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Taken item'), ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Free item'), ('b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3', 'a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'Other item');
-- Seed the one purchase. The seed adapts to the schema so it keeps working after task 3, which
-- moves buyer identity from purchases into purchase_buyers.
do $seed$
declare pid uuid;
begin
  if to_regclass('public.purchase_buyers') is null then
    insert into public.purchases (item_id, purchased_by_name, purchased_by_user_id)
      values ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Secret Buyer', '44444444-4444-4444-4444-444444444444');
  else
    insert into public.purchases (item_id, wishlist_id) values ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1') returning id into pid;
    insert into public.purchase_buyers (purchase_id, buyer_name, buyer_user_id)
      values (pid, 'Secret Buyer', '44444444-4444-4444-4444-444444444444');
  end if;
end $seed$;

select plan(54);

reset role;
set local role anon;
set local "request.jwt.claims" to '{"role": "anon"}';

select is(grid.rows($q$select 1 from public.wishlists$q$), 0, 'B: anon cannot list wishlists');
select is(grid.rows($q$select 1 from public.items$q$), 0, 'B: anon cannot list items');
select is(grid.rows($q$select 1 from public.purchases p where to_jsonb(p)::text ~* 'Secret Buyer|44444444-4444-4444-4444-444444444444'$q$), 0, 'K: anon cannot read the buyer name or user id');
select is(grid.rows($q$select 1 from public.purchases where item_id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$), 1, 'CREATOR-EXCL: anon still sees that a purchased item is taken');
select is(grid.outcome($q$insert into public.purchases select * from jsonb_populate_record(null::public.purchases, '{"id": "c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0", "item_id": "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2", "created_at": "2026-01-01T00:00:00Z"}')$q$), 'error:42501', 'E: anon cannot insert a purchase directly');
select is(grid.outcome($q$truncate public.wishlists$q$), 'error:42501', 'L: anon cannot TRUNCATE public.wishlists');
select is(grid.outcome($q$truncate public.items$q$), 'error:42501', 'L: anon cannot TRUNCATE public.items');
select is(grid.outcome($q$truncate public.purchases$q$), 'error:42501', 'L: anon cannot TRUNCATE public.purchases');
select ok(grid.outcome($q$update public.wishlists set title = 'x'$q$) in ('error:42501', 'rows:0'), 'B: anon cannot update any row of public.wishlists');
select ok(grid.outcome($q$delete from public.wishlists$q$) in ('error:42501', 'rows:0'), 'B: anon cannot delete any row of public.wishlists');
select ok(grid.outcome($q$update public.items set title = 'x'$q$) in ('error:42501', 'rows:0'), 'B: anon cannot update any row of public.items');
select ok(grid.outcome($q$delete from public.items$q$) in ('error:42501', 'rows:0'), 'B: anon cannot delete any row of public.items');
select ok(grid.outcome($q$update public.purchases set created_at = now()$q$) in ('error:42501', 'rows:0'), 'E: anon cannot update any row of public.purchases');
select ok(grid.outcome($q$delete from public.purchases$q$) in ('error:42501', 'rows:0'), 'E: anon cannot delete any row of public.purchases');
select is(grid.outcome($q$insert into public.wishlists (owner_id, title) values ('11111111-1111-1111-1111-111111111111', 'x')$q$), 'error:42501', 'B: anon cannot insert a wishlist');
select is(grid.outcome($q$insert into public.items (wishlist_id, title) values ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'x')$q$), 'error:42501', 'B: anon cannot insert an item');
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is(grid.rows($q$select 1 from public.wishlists$q$), 1, 'B: creator sees only their own wishlist');
select is(grid.rows($q$select 1 from public.items$q$), 2, 'B: creator sees only the items of their own wishlist');
select is(grid.rows($q$select 1 from public.purchases p where to_jsonb(p)::text ~* 'Secret Buyer|44444444-4444-4444-4444-444444444444'$q$), 0, 'K: creator cannot read the buyer name or user id');
select is(grid.rows($q$select 1 from public.purchases$q$), 0, 'CREATOR-EXCL: creator reads no purchase row');
select is(grid.outcome($q$insert into public.purchases select * from jsonb_populate_record(null::public.purchases, '{"id": "c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0", "item_id": "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2", "created_at": "2026-01-01T00:00:00Z"}')$q$), 'error:42501', 'E: creator cannot reserve their own untaken item');
select is(grid.outcome($q$insert into public.purchases select * from jsonb_populate_record(null::public.purchases, '{"id": "c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0", "item_id": "b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1", "created_at": "2026-01-01T00:00:00Z"}')$q$), 'error:42501', 'E: creator gets the same error on their own taken item (no status oracle)');
select is(grid.outcome($q$truncate public.wishlists$q$), 'error:42501', 'L: creator cannot TRUNCATE public.wishlists');
select is(grid.outcome($q$truncate public.items$q$), 'error:42501', 'L: creator cannot TRUNCATE public.items');
select is(grid.outcome($q$truncate public.purchases$q$), 'error:42501', 'L: creator cannot TRUNCATE public.purchases');
select ok(grid.outcome($q$update public.purchases set created_at = now()$q$) in ('error:42501', 'rows:0'), 'E: creator cannot update any row of public.purchases');
select ok(grid.outcome($q$delete from public.purchases$q$) in ('error:42501', 'rows:0'), 'E: creator cannot delete any row of public.purchases');
select is(grid.outcome($q$update public.wishlists set title = 'renamed'$q$), 'rows:1', 'CONTROL: creator can update their own wishlist');
select is(grid.outcome($q$insert into public.wishlists (owner_id, title) values ('22222222-2222-2222-2222-222222222222', 'x')$q$), 'error:42501', 'B: creator cannot create a wishlist owned by someone else');
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

select is(grid.rows($q$select 1 from public.wishlists$q$), 1, 'B: another signed-in user sees only their own wishlist');
select is(grid.rows($q$select 1 from public.items$q$), 1, 'B: another signed-in user sees only their own items');
select is(grid.rows($q$select 1 from public.purchases p where to_jsonb(p)::text ~* 'Secret Buyer|44444444-4444-4444-4444-444444444444'$q$), 0, 'K: another signed-in user cannot read the buyer name or user id');
select is(grid.rows($q$select 1 from public.purchases where item_id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$), 1, 'CREATOR-EXCL: a non-creator signed-in user sees that an item is taken');
select is(grid.outcome($q$insert into public.purchases select * from jsonb_populate_record(null::public.purchases, '{"id": "c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0", "item_id": "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2", "created_at": "2026-01-01T00:00:00Z"}')$q$), 'error:42501', 'E: a signed-in user cannot insert a purchase directly');
select is(grid.outcome($q$insert into public.purchases select * from jsonb_populate_record(null::public.purchases, '{"id": "c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0", "item_id": "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2", "created_at": "2026-01-01T00:00:00Z", "purchased_by_user_id": "33333333-3333-3333-3333-333333333333"}')$q$), 'error:42501', 'E: purchased_by_user_id cannot be spoofed');
select is(grid.outcome($q$truncate public.wishlists$q$), 'error:42501', 'L: other user cannot TRUNCATE public.wishlists');
select is(grid.outcome($q$truncate public.items$q$), 'error:42501', 'L: other user cannot TRUNCATE public.items');
select is(grid.outcome($q$truncate public.purchases$q$), 'error:42501', 'L: other user cannot TRUNCATE public.purchases');
select ok(grid.outcome($q$update public.wishlists set title = 'x' where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$) in ('error:42501', 'rows:0'), 'B: another user cannot update someone else''s wishlist');
select ok(grid.outcome($q$delete from public.items where wishlist_id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$) in ('error:42501', 'rows:0'), 'B: another user cannot delete someone else''s items');
select ok(grid.outcome($q$update public.purchases set created_at = now()$q$) in ('error:42501', 'rows:0'), 'E: another user cannot update purchases');
select ok(grid.outcome($q$delete from public.purchases$q$) in ('error:42501', 'rows:0'), 'E: another user cannot delete purchases');
select is(grid.outcome($q$insert into public.wishlists (owner_id, title) values ('11111111-1111-1111-1111-111111111111', 'x')$q$), 'error:42501', 'B: another user cannot create a wishlist owned by the creator');
select is(grid.outcome($q$insert into public.items (wishlist_id, title) values ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'x')$q$), 'error:42501', 'B: another user cannot add an item to someone else''s wishlist');
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

select is(grid.rows($q$select 1 from public.wishlists$q$), 0, 'B: a signed-in guest cannot list wishlists');
select is(grid.rows($q$select 1 from public.items$q$), 0, 'B: a signed-in guest cannot list items');
select is(grid.rows($q$select 1 from public.purchases p where to_jsonb(p)::text ~* 'Secret Buyer|44444444-4444-4444-4444-444444444444'$q$), 0, 'K: a signed-in guest cannot read the buyer name or user id');
select is(grid.rows($q$select 1 from public.purchases where item_id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$), 1, 'CREATOR-EXCL: a signed-in guest sees that an item is taken');
select is(grid.outcome($q$insert into public.purchases select * from jsonb_populate_record(null::public.purchases, '{"id": "c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0", "item_id": "b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2", "created_at": "2026-01-01T00:00:00Z"}')$q$), 'error:42501', 'E: a signed-in guest cannot insert a purchase directly');
select is(grid.outcome($q$truncate public.wishlists$q$), 'error:42501', 'L: signed-in guest cannot TRUNCATE public.wishlists');
select is(grid.outcome($q$truncate public.items$q$), 'error:42501', 'L: signed-in guest cannot TRUNCATE public.items');
select is(grid.outcome($q$truncate public.purchases$q$), 'error:42501', 'L: signed-in guest cannot TRUNCATE public.purchases');
select ok(grid.outcome($q$update public.wishlists set title = 'x'$q$) in ('error:42501', 'rows:0'), 'B: a signed-in guest cannot update wishlists');
select ok(grid.outcome($q$delete from public.wishlists$q$) in ('error:42501', 'rows:0'), 'B: a signed-in guest cannot delete wishlists');

reset role;
select * from finish();
rollback;
