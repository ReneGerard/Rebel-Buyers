-- Live baseline of the production schema (project ookqbhipqnocwfkbaneo).
--
-- Reconstructed on 2026-10-19 from the live catalog with read-only queries
-- (pg_attribute, pg_constraint, pg_indexes, pg_policies, pg_class.relacl, pg_trigger,
-- pg_proc, pg_publication_tables, pg_default_acl). It replaces the four earlier migration
-- files, which could not rebuild the database (docs/security-audit.md, findings A and H).
--
-- THIS FILE REPRODUCES THE LIVE SCHEMA AS IT IS, KNOWN PROBLEMS INCLUDED. Nothing is fixed here.
-- Open findings that this baseline still carries (all fixed later, see docs/sprint-1.md task 3):
--   B  wishlists/items SELECT policies `using (true)` for role public
--   D  public.purchases is in the supabase_realtime publication
--   E  purchases INSERT policy `with check (true)`
--   I  share_slug default = substr(md5(random()), 1, 10)
--   K  purchases SELECT policy exposes purchased_by_name / purchased_by_user_id
--   L  anon and authenticated hold ALL table privileges, TRUNCATE included
--   M  duplicate overlapping policies on wishlists and items
--   N  purchases.purchased_by_user_id FK is NO ACTION
--   O  set_updated_at has a mutable search_path
--
-- Do NOT apply this file to production: the objects already exist there. The production
-- migration history is aligned separately (docs/baseline-history-repair.md).
--
-- Not captured / known differences from live:
--   * set_updated_at body: live has CRLF line endings, this file uses LF (no behavior change).
--   * Object ownership is left to the migration runner (postgres on Supabase; live owner is postgres).
--   * Table and function grants to anon/authenticated/service_role are written out explicitly. On
--     Supabase they also come from default privileges (pg_default_acl, owner postgres, schema public).
--     The first capture of this file missed pg_default_acl, so the default privileges were not
--     recorded and a stack that lacks them (the local Supabase stack used by CI) tested later REVOKEs
--     vacuously. They are now recorded by the ALTER DEFAULT PRIVILEGES statements right below this
--     header. In production they already exist, so this changes nothing there (this file is only
--     marked as applied during the history repair, never executed in production). Live values:
--     tables arwdDxtm, sequences rwU, functions X, each to postgres, anon, authenticated, service_role.
--   * Live runs Postgres 17, whose ALL privilege on tables includes MAINTAIN (relacl letter `m`).
--     `grant all` reproduces it on 17; a Postgres 16 local database shows `arwdDxt` instead.
--   * Extensions present live: plpgsql, pg_stat_statements, uuid-ossp, pgcrypto, supabase_vault. They
--     are provided by the Supabase platform; gen_random_uuid() and md5()/random() used here are in
--     pg_catalog, so none of them is created here.
--   * The supabase_realtime publication itself exists on every Supabase database; only its
--     membership (public.purchases) is set here. Live also has supabase_realtime_messages_publication
--     (platform-owned, not touched).
--   * No sequences, views, enums, custom types, table or column comments, column-level grants or
--     triggers other than the two below exist in schema public.
--   * auth schema, storage, Auth settings and Realtime runtime behavior are out of scope.

-- ---------------------------------------------------------------------------
-- Default privileges (live pg_default_acl, role postgres, schema public). Objects created below,
-- and by every later migration, are opened to the API roles unless the migration revokes it.
-- ---------------------------------------------------------------------------

alter default privileges for role postgres in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on functions to postgres, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Tables (column order matches live)
-- ---------------------------------------------------------------------------

create table public.wishlists (
  id uuid not null default gen_random_uuid(),
  owner_id uuid not null,
  title text not null,
  description text,
  share_slug text not null default substr(md5((random())::text), 1, 10),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wishlists_pkey primary key (id),
  constraint wishlists_share_slug_key unique (share_slug),
  constraint wishlists_owner_id_fkey foreign key (owner_id) references auth.users (id) on delete cascade
);

create table public.items (
  id uuid not null default gen_random_uuid(),
  wishlist_id uuid not null,
  title text not null,
  merchant_url text,
  price numeric(10, 2),
  image_url text,
  note text,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint items_pkey primary key (id),
  constraint items_wishlist_id_fkey foreign key (wishlist_id) references public.wishlists (id) on delete cascade
);

create table public.purchases (
  id uuid not null default gen_random_uuid(),
  item_id uuid not null,
  purchased_by_name text,
  purchased_by_user_id uuid,
  created_at timestamptz not null default now(),
  constraint purchases_pkey primary key (id),
  constraint purchases_item_id_key unique (item_id),
  constraint purchases_item_id_fkey foreign key (item_id) references public.items (id) on delete cascade,
  constraint purchases_purchased_by_user_id_fkey foreign key (purchased_by_user_id) references auth.users (id)
);

-- ---------------------------------------------------------------------------
-- Indexes (the unique/primary key indexes are created by the constraints above)
-- ---------------------------------------------------------------------------

create index idx_wishlists_share_slug on public.wishlists using btree (share_slug);
create index idx_items_wishlist_id on public.items using btree (wishlist_id);
create index idx_purchases_item_id on public.purchases using btree (item_id);

-- ---------------------------------------------------------------------------
-- Function and triggers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
 returns trigger
 language plpgsql
as $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

create trigger wishlists_updated_at
  before update on public.wishlists
  for each row execute function public.set_updated_at();

create trigger items_updated_at
  before update on public.items
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.wishlists enable row level security;
alter table public.items enable row level security;
alter table public.purchases enable row level security;

-- wishlists (6 policies, all for role public; overlapping on purpose, see M)

create policy "Anyone can view wishlists via public access" on public.wishlists
  as permissive for select to public
  using (true);

create policy "Owners can delete their wishlists" on public.wishlists
  as permissive for delete to public
  using (auth.uid() = owner_id);

create policy "Owners can insert their wishlists" on public.wishlists
  as permissive for insert to public
  with check (auth.uid() = owner_id);

create policy "Owners can manage their wishlists" on public.wishlists
  as permissive for all to public
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "Owners can select their wishlists" on public.wishlists
  as permissive for select to public
  using (auth.uid() = owner_id);

create policy "Owners can update their wishlists" on public.wishlists
  as permissive for update to public
  using (auth.uid() = owner_id);

-- items (6 policies, all for role public)

create policy "Anyone can view items" on public.items
  as permissive for select to public
  using (true);

create policy "Owners can delete items in their wishlists" on public.items
  as permissive for delete to public
  using (exists (
    select 1 from public.wishlists
    where wishlists.id = items.wishlist_id and wishlists.owner_id = auth.uid()
  ));

create policy "Owners can insert items in their wishlists" on public.items
  as permissive for insert to public
  with check (exists (
    select 1 from public.wishlists
    where wishlists.id = items.wishlist_id and wishlists.owner_id = auth.uid()
  ));

create policy "Owners can manage items in their wishlists" on public.items
  as permissive for all to public
  using (auth.uid() = (
    select wishlists.owner_id from public.wishlists where wishlists.id = items.wishlist_id
  ))
  with check (auth.uid() = (
    select wishlists.owner_id from public.wishlists where wishlists.id = items.wishlist_id
  ));

create policy "Owners can select items in their wishlists" on public.items
  as permissive for select to public
  using (exists (
    select 1 from public.wishlists
    where wishlists.id = items.wishlist_id and wishlists.owner_id = auth.uid()
  ));

create policy "Owners can update items in their wishlists" on public.items
  as permissive for update to public
  using (exists (
    select 1 from public.wishlists
    where wishlists.id = items.wishlist_id and wishlists.owner_id = auth.uid()
  ));

-- purchases (2 policies; no UPDATE or DELETE policy exists live)

create policy "Anyone can mark an item as purchased" on public.purchases
  as permissive for insert to public
  with check (true);

create policy "Non-owners can view purchase status" on public.purchases
  as permissive for select to public
  using (
    (auth.uid() is distinct from (
      select w.owner_id
      from public.items i join public.wishlists w on w.id = i.wishlist_id
      where i.id = purchases.item_id
    ))
    or (auth.uid() is null)
  );

-- ---------------------------------------------------------------------------
-- Grants (live relacl: arwdDxtm for postgres, anon, authenticated, service_role; see L)
-- ---------------------------------------------------------------------------

grant all on table public.wishlists to anon, authenticated, service_role;
grant all on table public.items to anon, authenticated, service_role;
grant all on table public.purchases to anon, authenticated, service_role;

-- Live proacl: {=X/postgres, postgres, anon, authenticated, service_role} (EXECUTE to PUBLIC
-- is the Postgres default for new functions; the three roles come from default privileges).
grant execute on function public.set_updated_at() to public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Realtime (see D)
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.purchases;
