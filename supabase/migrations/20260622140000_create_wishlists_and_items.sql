create table if not exists public.wishlists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.items (
  id uuid primary key default gen_random_uuid(),
  wishlist_id uuid not null references public.wishlists (id) on delete cascade,
  title text not null,
  merchant_url text,
  price numeric,
  image_url text,
  note text,
  created_at timestamptz not null default now()
);

alter table public.wishlists enable row level security;
alter table public.items enable row level security;

create policy "Owners can select their wishlists"
  on public.wishlists for select
  using (auth.uid() = owner_id);

create policy "Owners can insert their wishlists"
  on public.wishlists for insert
  with check (auth.uid() = owner_id);

create policy "Owners can update their wishlists"
  on public.wishlists for update
  using (auth.uid() = owner_id);

create policy "Owners can delete their wishlists"
  on public.wishlists for delete
  using (auth.uid() = owner_id);

create policy "Owners can select items in their wishlists"
  on public.items for select
  using (
    exists (
      select 1 from public.wishlists
      where wishlists.id = items.wishlist_id
        and wishlists.owner_id = auth.uid()
    )
  );

create policy "Owners can insert items in their wishlists"
  on public.items for insert
  with check (
    exists (
      select 1 from public.wishlists
      where wishlists.id = items.wishlist_id
        and wishlists.owner_id = auth.uid()
    )
  );

create policy "Owners can update items in their wishlists"
  on public.items for update
  using (
    exists (
      select 1 from public.wishlists
      where wishlists.id = items.wishlist_id
        and wishlists.owner_id = auth.uid()
    )
  );

create policy "Owners can delete items in their wishlists"
  on public.items for delete
  using (
    exists (
      select 1 from public.wishlists
      where wishlists.id = items.wishlist_id
        and wishlists.owner_id = auth.uid()
    )
  );
