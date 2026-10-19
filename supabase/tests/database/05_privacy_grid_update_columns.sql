-- Privacy grid, part 5: column-limited UPDATE on wishlists and items (docs/decisions.md, task 3b).
--   * PATCHing id as the creator gives the same error on a taken and on a free item (and on a list
--     with and without a reservation); a table-wide UPDATE would raise the FK error 23503 only on the
--     taken one, a purchase status oracle;
--   * items.wishlist_id cannot be changed, so an item cannot be moved to drop its reservation when
--     the old list is deleted (purchases.wishlist_id cascades);
--   * owner_id and share_slug are not client-writable; the columns the app edits still are.
-- Test descriptions start with the finding ID (E: status oracle, L: excess privilege).
begin;
create extension if not exists pgtap with schema extensions;

create schema grid;
grant usage on schema grid to anon, authenticated;
-- grid.err() runs a statement as the current role and always rolls it back: 'rows:<n>' on success,
-- otherwise '<sqlstate>:<message>' so two errors can be compared message for message.
create function grid.err(q text) returns text language plpgsql as $f$
declare n bigint;
begin
  begin
    execute q;
    get diagnostics n = row_count;
    raise exception using errcode = 'GR001', message = 'rows:' || n;
  exception
    when sqlstate 'GR001' then return sqlerrm;
    when others then return sqlstate || ':' || sqlerrm;
  end;
end $f$;

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'creator@example.test'), ('22222222-2222-2222-2222-222222222222', 'other@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'buyer@example.test');
insert into public.wishlists (id, owner_id, title, share_slug) values
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', '11111111-1111-1111-1111-111111111111', 'Creator list', 'grid-slug-1'),
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', '22222222-2222-2222-2222-222222222222', 'Other list (no reservation)', 'grid-slug-2'),
  ('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3', '11111111-1111-1111-1111-111111111111', 'Creator second list', 'grid-slug-3');
insert into public.items (id, wishlist_id, title) values
  ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Taken item'),
  ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Free item'),
  ('b3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3', 'a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2', 'Other item');
do $seed$
declare pid uuid;
begin
  insert into public.purchases (item_id, wishlist_id) values ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1') returning id into pid;
  insert into public.purchase_buyers (purchase_id, buyer_name, buyer_user_id)
    values (pid, 'Secret Buyer', '44444444-4444-4444-4444-444444444444');
end $seed$;

select plan(12);

-- creator ----------------------------------------------------------------------------------------
reset role;
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select is(
  grid.err($q$update public.items set id = gen_random_uuid() where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$),
  grid.err($q$update public.items set id = gen_random_uuid() where id = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2'$q$),
  'E: PATCH of items.id gives the creator the same error on a taken and on a free item');
select is(
  grid.err($q$update public.items set id = gen_random_uuid() where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$),
  '42501:permission denied for table items', 'L: the creator cannot update items.id (permission denied, not an FK error)');
select is(
  grid.err($q$update public.wishlists set id = gen_random_uuid() where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$),
  grid.err($q$update public.wishlists set id = gen_random_uuid() where id = 'a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3'$q$),
  'E: PATCH of wishlists.id gives the creator the same error on a list with and without a reservation');
select is(
  grid.err($q$update public.wishlists set id = gen_random_uuid() where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$),
  '42501:permission denied for table wishlists', 'L: the creator cannot update wishlists.id');

select is(
  grid.err($q$update public.items set wishlist_id = 'a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3' where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$),
  '42501:permission denied for table items', 'L: the creator cannot move a taken item to another of their lists (items.wishlist_id)');
select is(
  grid.err($q$update public.items set wishlist_id = 'a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3' where id = 'b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2'$q$),
  '42501:permission denied for table items', 'L: the creator cannot move a free item to another of their lists (items.wishlist_id)');
select is(
  grid.err($q$update public.wishlists set owner_id = '22222222-2222-2222-2222-222222222222' where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$),
  '42501:permission denied for table wishlists', 'L: the creator cannot transfer a list (wishlists.owner_id)');
select is(
  grid.err($q$update public.wishlists set share_slug = 'chosen' where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$),
  '42501:permission denied for table wishlists', 'L: the creator cannot choose the share_slug');

select is(
  grid.err($q$update public.items set title = 't', merchant_url = 'https://example.test', price = 1, image_url = 'https://example.test/i.png', note = 'n', position = 3 where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'$q$),
  'rows:1', 'CONTROL: the creator can still update every column the app edits on an item');
select is(
  grid.err($q$update public.wishlists set title = 't', description = 'd' where id = 'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'$q$),
  'rows:1', 'CONTROL: the creator can still update title and description of a list');

-- as the table owner: nothing moved, the reservation is intact -----------------------------------
reset role;
select is(
  (select wishlist_id from public.items where id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'),
  'a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1'::uuid, 'L: the taken item is still in its original list');
select is(
  (select count(*)::int from public.purchases p join public.items i on i.id = p.item_id and i.wishlist_id = p.wishlist_id
   where p.item_id = 'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1'),
  1, 'L: the reservation still matches its item and list');

select * from finish();
rollback;
