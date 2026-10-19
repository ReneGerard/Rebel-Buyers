-- Privacy fix (docs/sprint-1.md task 3). Fixes B, C (remaining part), D, E, I, K, L, M, N, O
-- from docs/security-audit.md.
--
-- After this migration:
--   * purchases holds only (id, item_id, wishlist_id, created_at); buyer identity lives in
--     purchase_buyers, which has RLS on, zero policies and no client privileges (K);
--   * the only way to reserve an item is reserve_item(), which refuses the creator before it looks
--     at purchase status and with one generic error (E, C);
--   * the public list page reads through get_shared_wishlist(); wishlists and items are no longer
--     readable by guests, so lists cannot be enumerated (B);
--   * the creator-exclusion on purchases goes through the SECURITY DEFINER helper
--     is_wishlist_owner(), so anon needs no privilege at all on wishlists/items;
--   * one policy per command on every table (M), no TRUNCATE or other excess grants (L);
--   * set_updated_at has a pinned search_path (O), share_slug comes from gen_random_bytes (I),
--     the buyer user FK is ON DELETE SET NULL (N);
--   * purchases stays in the supabase_realtime publication (D); the client subscription filters on
--     wishlist_id. purchase_buyers is not published.
--
-- Data: the existing purchase rows keep their buyer name and user id (copied into purchase_buyers
-- before the old columns are dropped; the migration aborts instead of losing a buyer). Existing
-- share_slug values are regenerated, so existing share links stop working (test data only).
--
-- Do NOT apply to production from a Claude session (docs/sprint-1.md, "Rules for every database
-- change"): the owner dumps the tables first, CI passes the grid, then a separate approved session
-- applies it.

begin;

-- ---------------------------------------------------------------------------
-- purchases.wishlist_id (copied from the item, used for the Realtime filter)
-- ---------------------------------------------------------------------------

alter table public.purchases add column wishlist_id uuid;

update public.purchases p
set wishlist_id = i.wishlist_id
from public.items i
where i.id = p.item_id;

alter table public.purchases alter column wishlist_id set not null;
alter table public.purchases
  add constraint purchases_wishlist_id_fkey
  foreign key (wishlist_id) references public.wishlists (id) on delete cascade;
create index idx_purchases_wishlist_id on public.purchases using btree (wishlist_id);

-- ---------------------------------------------------------------------------
-- purchase_buyers: buyer identity, unreachable from any client role
-- ---------------------------------------------------------------------------

create table public.purchase_buyers (
  purchase_id uuid not null,
  buyer_name text not null,
  buyer_user_id uuid,
  constraint purchase_buyers_pkey primary key (purchase_id),
  constraint purchase_buyers_purchase_id_fkey
    foreign key (purchase_id) references public.purchases (id) on delete cascade,
  constraint purchase_buyers_buyer_user_id_fkey
    foreign key (buyer_user_id) references auth.users (id) on delete set null,
  constraint purchase_buyers_buyer_name_check check (char_length(btrim(buyer_name)) between 1 and 100)
);

alter table public.purchase_buyers enable row level security;
-- No policy on purpose. Supabase default privileges grant new tables to anon/authenticated: undo it.
revoke all on table public.purchase_buyers from anon, authenticated;

-- Preserve the existing buyers, and abort rather than lose one.
do $$
begin
  if exists (
    select 1 from public.purchases
    where purchased_by_name is null or btrim(purchased_by_name) = ''
  ) then
    raise exception 'privacy_fix: a purchase has no buyer name, fix the data before migrating';
  end if;
end
$$;

insert into public.purchase_buyers (purchase_id, buyer_name, buyer_user_id)
select id, purchased_by_name, purchased_by_user_id from public.purchases;

do $$
begin
  if (select count(*) from public.purchases) <> (select count(*) from public.purchase_buyers) then
    raise exception 'privacy_fix: purchase_buyers row count differs from purchases, aborting';
  end if;
end
$$;

-- Dropping the columns also drops purchases_purchased_by_user_id_fkey (the NO ACTION FK, N).
alter table public.purchases
  drop column purchased_by_name,
  drop column purchased_by_user_id;

-- ---------------------------------------------------------------------------
-- Functions (all SECURITY DEFINER, search_path pinned, EXECUTE only for anon and authenticated)
-- ---------------------------------------------------------------------------

-- True when the caller owns the wishlist. Lets the purchases policy exclude the creator without
-- giving anon any privilege on wishlists/items. Tells a caller nothing but their own ownership.
create function public.is_wishlist_owner(p_wishlist_id uuid)
  returns boolean
  language sql
  stable
  security definer
  set search_path = ''
as $$
  select exists (
    select 1 from public.wishlists w
    where w.id = p_wishlist_id and w.owner_id = (select auth.uid())
  );
$$;

-- Reserves an item for the caller (signed in or anonymous). The creator check comes first and
-- uses one generic error, so the creator learns nothing about purchase status.
create function public.reserve_item(p_item_id uuid, p_buyer_name text)
  returns void
  language plpgsql
  security definer
  set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_wishlist_id uuid;
  v_owner_id uuid;
  v_name text := btrim(coalesce(p_buyer_name, ''));
  v_purchase_id uuid;
begin
  select i.wishlist_id, w.owner_id into v_wishlist_id, v_owner_id
  from public.items i
  join public.wishlists w on w.id = i.wishlist_id
  where i.id = p_item_id;

  if not found or (v_uid is not null and v_uid = v_owner_id) then
    raise exception 'cannot reserve this item' using errcode = '42501';
  end if;

  if char_length(v_name) not between 1 and 100 then
    raise exception 'invalid buyer name' using errcode = '22023';
  end if;

  -- A second reservation of the same item raises unique_violation (23505) on purchases_item_id_key.
  insert into public.purchases (item_id, wishlist_id)
  values (p_item_id, v_wishlist_id)
  returning id into v_purchase_id;

  insert into public.purchase_buyers (purchase_id, buyer_name, buyer_user_id)
  values (v_purchase_id, v_name, v_uid);
end;
$$;

-- The public list page: the list, its items and a "taken" flag. taken is null for the creator.
-- Returns null when the slug is unknown.
create function public.get_shared_wishlist(p_slug text)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = ''
as $$
declare
  v_wishlist public.wishlists;
  v_is_owner boolean;
begin
  select * into v_wishlist from public.wishlists where share_slug = p_slug;
  if not found then
    return null;
  end if;

  v_is_owner := auth.uid() is not null and auth.uid() = v_wishlist.owner_id;

  return jsonb_build_object(
    'id', v_wishlist.id,
    'title', v_wishlist.title,
    'description', v_wishlist.description,
    'is_owner', v_is_owner,
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', i.id,
          'title', i.title,
          'merchant_url', i.merchant_url,
          'price', i.price,
          'image_url', i.image_url,
          'note', i.note,
          'created_at', i.created_at,
          'taken', case
            when v_is_owner then null
            else exists (select 1 from public.purchases p where p.item_id = i.id)
          end
        )
        order by i.created_at desc, i.id
      )
      from public.items i
      where i.wishlist_id = v_wishlist.id
    ), '[]'::jsonb)
  );
end;
$$;

-- Postgres grants EXECUTE to PUBLIC on new functions; Supabase default privileges also grant the
-- API roles. Reset, then grant exactly what is needed.
revoke execute on function public.is_wishlist_owner(uuid) from public, anon, authenticated;
revoke execute on function public.reserve_item(uuid, text) from public, anon, authenticated;
revoke execute on function public.get_shared_wishlist(text) from public, anon, authenticated;
grant execute on function public.is_wishlist_owner(uuid) to anon, authenticated;
grant execute on function public.reserve_item(uuid, text) to anon, authenticated;
grant execute on function public.get_shared_wishlist(text) to anon, authenticated;

alter function public.set_updated_at() set search_path = '';

-- ---------------------------------------------------------------------------
-- Policies: drop the broad and duplicate ones, then one policy per command (M)
-- ---------------------------------------------------------------------------

drop policy "Anyone can view wishlists via public access" on public.wishlists;
drop policy "Owners can delete their wishlists" on public.wishlists;
drop policy "Owners can insert their wishlists" on public.wishlists;
drop policy "Owners can manage their wishlists" on public.wishlists;
drop policy "Owners can select their wishlists" on public.wishlists;
drop policy "Owners can update their wishlists" on public.wishlists;

drop policy "Anyone can view items" on public.items;
drop policy "Owners can delete items in their wishlists" on public.items;
drop policy "Owners can insert items in their wishlists" on public.items;
drop policy "Owners can manage items in their wishlists" on public.items;
drop policy "Owners can select items in their wishlists" on public.items;
drop policy "Owners can update items in their wishlists" on public.items;

drop policy "Anyone can mark an item as purchased" on public.purchases;
drop policy "Non-owners can view purchase status" on public.purchases;

create policy wishlists_select_owner on public.wishlists
  for select to authenticated
  using ((select auth.uid()) = owner_id);

create policy wishlists_insert_owner on public.wishlists
  for insert to authenticated
  with check ((select auth.uid()) = owner_id);

create policy wishlists_update_owner on public.wishlists
  for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

create policy wishlists_delete_owner on public.wishlists
  for delete to authenticated
  using ((select auth.uid()) = owner_id);

create policy items_select_owner on public.items
  for select to authenticated
  using (exists (
    select 1 from public.wishlists w
    where w.id = items.wishlist_id and w.owner_id = (select auth.uid())
  ));

create policy items_insert_owner on public.items
  for insert to authenticated
  with check (exists (
    select 1 from public.wishlists w
    where w.id = items.wishlist_id and w.owner_id = (select auth.uid())
  ));

create policy items_update_owner on public.items
  for update to authenticated
  using (exists (
    select 1 from public.wishlists w
    where w.id = items.wishlist_id and w.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.wishlists w
    where w.id = items.wishlist_id and w.owner_id = (select auth.uid())
  ));

create policy items_delete_owner on public.items
  for delete to authenticated
  using (exists (
    select 1 from public.wishlists w
    where w.id = items.wishlist_id and w.owner_id = (select auth.uid())
  ));

-- Guests (anon and signed in) see that an item is taken, never who took it; the creator sees
-- nothing. There is no INSERT/UPDATE/DELETE policy: reservations only go through reserve_item().
create policy purchases_select_non_owner on public.purchases
  for select to anon, authenticated
  using (not public.is_wishlist_owner(wishlist_id));

-- ---------------------------------------------------------------------------
-- Grants (L): nothing beyond what the policies above use
-- ---------------------------------------------------------------------------

revoke all on table public.wishlists from anon, authenticated;
revoke all on table public.items from anon, authenticated;
revoke all on table public.purchases from anon, authenticated;

grant select, insert, update, delete on table public.wishlists to authenticated;
grant select, insert, update, delete on table public.items to authenticated;
grant select on table public.purchases to anon, authenticated;

-- ---------------------------------------------------------------------------
-- share_slug (I): 96 random bits from pgcrypto (extensions schema on Supabase, qualified because
-- the default is evaluated with the caller's search_path)
-- ---------------------------------------------------------------------------

alter table public.wishlists
  alter column share_slug set default encode(extensions.gen_random_bytes(12), 'hex');

update public.wishlists set share_slug = encode(extensions.gen_random_bytes(12), 'hex');

commit;
