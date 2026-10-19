-- Privacy grid, part 4: the task 3 functions and purchase_buyers (docs/sprint-1.md task 3, "Definition
-- of done"). Roles: anon, creator, another signed-in user (owns a different list), signed-in guest.
--   * reserve_item: the creator gets the same generic error whether the item is taken or not (E, C);
--     guests can reserve, the buyer comes from auth.uid() only, a second reservation fails;
--   * get_shared_wishlist: `taken` is null for the creator and a boolean for everyone else, and the
--     payload never carries buyer identity or the owner id (B, K);
--   * PUBLIC has no EXECUTE on the new functions; they are SECURITY DEFINER;
--   * purchase_buyers is unreachable from every client role (K); purchases keeps no identity column.
-- Test descriptions start with the finding ID.
begin;
create extension if not exists pgtap with schema extensions;

create schema grid;
grant usage on schema grid to anon, authenticated;
-- grid.err() runs a statement as the current role and always rolls it back. It returns 'ok' on
-- success, otherwise '<sqlstate>:<message>' so two errors can be compared message for message.
create function grid.err(q text) returns text language plpgsql as $f$
begin
  begin
    execute q;
    raise exception using errcode = 'GR001', message = 'ok';
  exception
    when sqlstate 'GR001' then return 'ok';
    when others then return sqlstate || ':' || sqlerrm;
  end;
end $f$;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'creator@example.test'), ('22222222-2222-2222-2222-222222222222', 'other@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'guest@example.test'), ('44444444-4444-4444-4444-444444444444', 'buyer@example.test');
insert into public.wishlists (id, owner_id, title, share_slug) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', '11111111-1111-1111-1111-111111111111', 'Creator list', 'grid-slug-1'),
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', '22222222-2222-2222-2222-222222222222', 'Other list', 'grid-slug-2');
insert into public.items (id, wishlist_id, title) values
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Taken item'), ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Free item'), ('b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3', 'a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'Other item');
do $seed$
declare pid uuid;
begin
  insert into public.purchases (item_id, wishlist_id) values ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1') returning id into pid;
  insert into public.purchase_buyers (purchase_id, buyer_name, buyer_user_id)
    values (pid, 'Secret Buyer', '44444444-4444-4444-4444-444444444444');
end $seed$;

select plan(40);

-- anon -----------------------------------------------------------------------------------------
reset role;
set local role anon;
set local "request.jwt.claims" to '{"role": "anon"}';

select is(grid.err($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'Anon')$q$), 'ok', 'E: anon can reserve a free item');
select is(grid.err($q$select public.reserve_item('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Anon')$q$) ~ '^23505:', true, 'E: anon reserving a taken item gets unique_violation');
select is(grid.err($q$select public.reserve_item('d0d0d0d0-d0d0-d0d0-d0d0-d0d0d0d0d0d0', 'Anon')$q$), '42501:cannot reserve this item', 'E: anon reserving an unknown item gets the generic error');
select is(grid.err($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', '   ')$q$) ~ '^22023:', true, 'E: a blank buyer name is refused');
select is(grid.err($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', repeat('x', 101))$q$) ~ '^22023:', true, 'E: a 101-character buyer name is refused');
select is(jsonb_array_length(public.get_shared_wishlist('grid-slug-1') -> 'items'), 2, 'B: anon reads a list through get_shared_wishlist');
select is(
  (select string_agg(e ->> 'title' || '=' || (e ->> 'taken'), ',' order by e ->> 'title')
   from jsonb_array_elements(public.get_shared_wishlist('grid-slug-1') -> 'items') e),
  'Free item=false,Taken item=true', 'B: anon sees taken flags');
select is((public.get_shared_wishlist('grid-slug-1') ->> 'is_owner')::boolean, false, 'B: anon is not the owner');
select is(public.get_shared_wishlist('grid-slug-1')::text !~* 'Secret Buyer|44444444|11111111', true, 'K: the shared payload carries no buyer identity or owner id (anon)');
select is(public.get_shared_wishlist('no-such-slug'), null::jsonb, 'B: an unknown slug returns null');
select is(grid.err($q$select * from public.purchase_buyers$q$), '42501:permission denied for table purchase_buyers', 'K: anon cannot read purchase_buyers');
select is(grid.err($q$insert into public.purchase_buyers (purchase_id, buyer_name) values (gen_random_uuid(), 'x')$q$) ~ '^42501:', true, 'K: anon cannot write purchase_buyers');

-- creator --------------------------------------------------------------------------------------
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is(
  grid.err($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'Me')$q$),
  grid.err($q$select public.reserve_item('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Me')$q$),
  'E: creator gets the identical error on a free and on a taken item (no status oracle)');
select is(grid.err($q$select public.reserve_item('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Me')$q$), '42501:cannot reserve this item', 'E: the creator error is the generic one');
select is(
  grid.err($q$select public.reserve_item('d0d0d0d0-d0d0-d0d0-d0d0-d0d0d0d0d0d0', 'Me')$q$),
  grid.err($q$select public.reserve_item('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Me')$q$),
  'E: creator error on an unknown item matches the one on a taken item');
select is((public.get_shared_wishlist('grid-slug-1') ->> 'is_owner')::boolean, true, 'C: creator is recognised as owner');
select is(jsonb_array_length(public.get_shared_wishlist('grid-slug-1') -> 'items'), 2, 'C: creator still sees the items');
select is(
  (select count(*)::int from jsonb_array_elements(public.get_shared_wishlist('grid-slug-1') -> 'items') e
   where e -> 'taken' is distinct from 'null'::jsonb),
  0, 'C: creator gets a null taken flag on every item');
select is(public.get_shared_wishlist('grid-slug-1')::text !~* 'Secret Buyer|44444444', true, 'K: the shared payload carries no buyer identity (creator)');

-- another signed-in user (owns list 2) ---------------------------------------------------------
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

select is(
  (select string_agg(e ->> 'title' || '=' || (e ->> 'taken'), ',' order by e ->> 'title')
   from jsonb_array_elements(public.get_shared_wishlist('grid-slug-1') -> 'items') e),
  'Free item=false,Taken item=true', 'B: another signed-in user sees taken flags on the creator list');
select is((public.get_shared_wishlist('grid-slug-1') ->> 'is_owner')::boolean, false, 'B: another signed-in user is not the owner of the creator list');
select is(grid.err($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'Other')$q$), 'ok', 'E: another signed-in user can reserve on the creator list');
select is(grid.err($q$select public.reserve_item('b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3', 'Other')$q$), '42501:cannot reserve this item', 'E: a creator cannot reserve on their own list (second list)');

-- signed-in guest: real (persisted) reservations -----------------------------------------------
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

select is(grid.err($q$select public.reserve_item('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Guest')$q$) ~ '^23505:', true, 'E: signed-in guest reserving a taken item gets unique_violation');
select lives_ok($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', '  Alice  ')$q$, 'E: signed-in guest reserves a free item');
select is(grid.err($q$select public.reserve_item('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'Alice')$q$) ~ '^23505:', true, 'E: a second reservation of the same item fails');
select is(grid.err($q$select * from public.purchase_buyers$q$), '42501:permission denied for table purchase_buyers', 'K: signed-in guest cannot read purchase_buyers');
select is(grid.err($q$insert into public.purchase_buyers (purchase_id, buyer_name) values (gen_random_uuid(), 'x')$q$) ~ '^42501:', true, 'K: signed-in guest cannot write purchase_buyers');

reset role;
set local role anon;
set local "request.jwt.claims" to '{"role": "anon"}';
select lives_ok($q$select public.reserve_item('b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3', 'Anon')$q$, 'E: anon reserves a free item');

-- as the table owner: what the reservations stored ----------------------------------------------
reset role;
select is(
  (select pb.buyer_name || '/' || pb.buyer_user_id from public.purchase_buyers pb join public.purchases p on p.id = pb.purchase_id
   where p.item_id = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2'),
  'Alice/33333333-3333-3333-3333-333333333333', 'E: buyer name is trimmed and buyer_user_id comes from auth.uid()');
select is(
  (select wishlist_id from public.purchases where item_id = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2'),
  'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'D: the purchase carries the wishlist_id of its item (Realtime filter)');
select is(
  (select pb.buyer_user_id from public.purchase_buyers pb join public.purchases p on p.id = pb.purchase_id
   where p.item_id = 'b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3'),
  null::uuid, 'E: an anonymous reservation stores no user id');

-- catalog --------------------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
   where p.pronamespace = 'public'::regnamespace and p.proname in ('reserve_item', 'get_shared_wishlist', 'is_wishlist_owner')
     and a.grantee = 0 and a.privilege_type = 'EXECUTE'),
  0, 'E: PUBLIC has no EXECUTE on reserve_item, get_shared_wishlist or is_wishlist_owner');
select is(
  (select count(*)::int from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.proname in ('reserve_item', 'get_shared_wishlist', 'is_wishlist_owner') and p.prosecdef),
  3, 'E: the three functions are SECURITY DEFINER');
select is(
  (select array_agg(attname::text order by attname) from pg_attribute
   where attrelid = 'public.purchases'::regclass and attnum > 0 and not attisdropped),
  array['created_at', 'id', 'item_id', 'wishlist_id'], 'K: purchases holds no buyer identity column');
select is(
  (select confdeltype::text from pg_constraint where conname = 'purchase_buyers_buyer_user_id_fkey'),
  'n', 'N: purchase_buyers.buyer_user_id is ON DELETE SET NULL');
select is(
  (select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'purchase_buyers'),
  0, 'K: purchase_buyers has zero policies');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.purchase_buyers'::regclass),
  'K: purchase_buyers has RLS enabled');
select ok(
  exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'purchases'),
  'D: purchases stays in the supabase_realtime publication (the subscription filters on wishlist_id)');
select ok(
  not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'purchase_buyers'),
  'K: purchase_buyers is not in the supabase_realtime publication');

select * from finish();
rollback;
